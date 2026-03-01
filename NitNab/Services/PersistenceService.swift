//
//  PersistenceService.swift
//  NitNab
//
//  Created by Lane Campbell (@lanec)
//

import Foundation
import AppKit

actor PersistenceService {
    
    static let shared = PersistenceService()
    
    private let userDefaults = UserDefaults.standard
    private let storagePathKey = "nitnab.storagePath"
    private let database = DatabaseService.shared
    private let ubiquitousContainerID = "iCloud.\(Bundle.main.bundleIdentifier ?? "com.example.nitnab")"
    
    private init() {}
    
    // MARK: - Storage Path Management
    
    /// Get the current storage path (iCloud Drive or custom folder)
    /// Always returns a path - defaults to iCloud Drive
    func getStoragePath() -> URL? {
        // Check if user has set a custom path
        if let pathString = userDefaults.string(forKey: storagePathKey), !pathString.isEmpty {
            return URL(fileURLWithPath: pathString)
        }
        
        // No custom path - use iCloud Drive as default
        return getDefaultiCloudPath()
    }
    
    /// Set a custom storage path
    func setStoragePath(_ url: URL) {
        userDefaults.set(url.path, forKey: storagePathKey)
    }
    
    /// Get default iCloud Drive path
    private func getDefaultiCloudPath() -> URL? {
        // Try app-specific ubiquitous container first (requires proper signing)
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: ubiquitousContainerID) {
            let nitnabPath = iCloudURL.appendingPathComponent("Documents/NitNab")
            return nitnabPath
        }

        // Fallback for unsigned Debug builds - use direct file path
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let iCloudDrivePath = homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Mobile Documents")
            .appendingPathComponent("com~apple~CloudDocs")
            .appendingPathComponent("NitNab")
        
        // Check if path exists
        return iCloudDrivePath
    }
    
    /// Check if iCloud Drive is available
    func isiCloudAvailable() -> Bool {
        return FileManager.default.url(forUbiquityContainerIdentifier: ubiquitousContainerID) != nil
    }
    
    // MARK: - File Persistence
    
    /// Save a transcription job with all its data using new folder structure
    func saveJob(_ job: TranscriptionJob) async throws {
        guard let storagePath = getStoragePath() else {
            throw PersistenceError.noStoragePath
        }
        
        // Create job folder: YYYY-MM-DD_HH-MM-SS_filename
        let timestamp = DateFormatter.filenameSafe.string(from: Date())
        let baseName = (job.audioFile.filename as NSString).deletingPathExtension
        let jobFolderName = "\(timestamp)_\(baseName)"
        let jobFolder = storagePath.appendingPathComponent(jobFolderName)
        
        // Create folder structure: Audio/, Transcript/, AI Summary/
        let audioFolder = jobFolder.appendingPathComponent("Audio")
        let transcriptFolder = jobFolder.appendingPathComponent("Transcript")
        let aiSummaryFolder = jobFolder.appendingPathComponent("AI Summary")
        
        try FileManager.default.createDirectory(at: audioFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: transcriptFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: aiSummaryFolder, withIntermediateDirectories: true)
        
        // 1. Copy audio file to Audio/
        let audioDestination = audioFolder.appendingPathComponent(job.audioFile.filename)
        if !FileManager.default.fileExists(atPath: audioDestination.path) {
            try FileManager.default.copyItem(at: job.audioFile.url, to: audioDestination)
        }
        
        // Insert into database
        try await database.insertTranscription(job, folderName: jobFolderName, audioPath: audioDestination.path)
        
        // 2. Save transcript to Transcript/
        if let result = job.result {
            let transcriptPath = transcriptFolder.appendingPathComponent("transcript.txt")
            try result.fullTranscript.write(to: transcriptPath, atomically: true, encoding: .utf8)
            
            // Save JSON metadata to Transcript/
            let metadataPath = transcriptFolder.appendingPathComponent("metadata.json")
            let metadata: [String: Any] = [
                "filename": job.audioFile.filename,
                "duration": job.audioFile.duration,
                "wordCount": result.wordCount,
                "characterCount": result.characterCount,
                "confidence": result.confidence,
                "language": result.language,
                "transcribedAt": ISO8601DateFormatter().string(from: job.completedAt ?? Date())
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try jsonData.write(to: metadataPath)
            
            // Update database with transcript path
            try await database.updateTranscriptionWithResult(job, transcriptPath: transcriptPath.path)
        }
    }
    
    /// Save just the transcript for an already-existing job
    func saveTranscript(for job: TranscriptionJob) async throws {
        guard let result = job.result else { return }

        guard let folderPath = job.folderPath else {
            throw PersistenceError.noStoragePath
        }

        let jobFolder = URL(fileURLWithPath: folderPath)
        let transcriptFolder = jobFolder.appendingPathComponent("Transcript")

        try FileManager.default.createDirectory(at: transcriptFolder, withIntermediateDirectories: true)

        // Save transcript.txt
        let transcriptPath = transcriptFolder.appendingPathComponent("transcript.txt")
        try result.fullTranscript.write(to: transcriptPath, atomically: true, encoding: .utf8)

        // Save metadata.json
        let metadataPath = transcriptFolder.appendingPathComponent("metadata.json")
        let metadata: [String: Any] = [
            "filename": job.audioFile.filename,
            "duration": job.audioFile.duration,
            "wordCount": result.wordCount,
            "characterCount": result.characterCount,
            "confidence": result.confidence,
            "language": result.language,
            "transcribedAt": ISO8601DateFormatter().string(from: job.completedAt ?? Date())
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        try jsonData.write(to: metadataPath)

        try await database.updateTranscriptionWithResult(job, transcriptPath: transcriptPath.path)
    }
    
    /// Load AI summary for a job from AI Summary/ folder
    func loadSummary(for job: TranscriptionJob) async throws -> String? {
        // Use the folderPath already stored in the job
        guard let folderPath = job.folderPath else { return nil }
        
        let jobFolder = URL(fileURLWithPath: folderPath)
        let summaryPath = jobFolder.appendingPathComponent("AI Summary/summary.txt")
        
        if FileManager.default.fileExists(atPath: summaryPath.path) {
            return try String(contentsOf: summaryPath, encoding: .utf8)
        }
        
        return nil
    }
    
    /// Save AI summary for a job to AI Summary/ folder
    func saveSummary(_ summary: String, for job: TranscriptionJob) async throws {
        // Use the folderPath already stored in the job
        guard let folderPath = job.folderPath else {
            throw PersistenceError.noStoragePath
        }

        let jobFolder = URL(fileURLWithPath: folderPath)
        let aiSummaryFolder = jobFolder.appendingPathComponent("AI Summary")
        try FileManager.default.createDirectory(at: aiSummaryFolder, withIntermediateDirectories: true)

        let summaryPath = aiSummaryFolder.appendingPathComponent("summary.txt")
        try summary.write(to: summaryPath, atomically: true, encoding: .utf8)

        try await database.updateSummaryPath(job.id, summaryPath: summaryPath.path)
    }
    
    /// Load chat history for a job from AI Summary/ folder
    func loadChatHistory(for job: TranscriptionJob) async throws -> [(role: String, content: String)] {
        // Use the folderPath already stored in the job
        guard let folderPath = job.folderPath else { return [] }

        let jobFolder = URL(fileURLWithPath: folderPath)
        let chatPath = jobFolder.appendingPathComponent("AI Summary/chat.json")

        guard FileManager.default.fileExists(atPath: chatPath.path) else { return [] }

        do {
            let jsonData = try Data(contentsOf: chatPath)
            guard let chatArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: String]] else {
                return []
            }

            return chatArray.compactMap { dict -> (role: String, content: String)? in
                guard let role = dict["role"], let content = dict["content"] else { return nil }
                return (role: role, content: content)
            }
        } catch {
            return []
        }
    }
    
    /// Save chat history for a job to AI Summary/ folder
    func saveChatHistory(_ messages: [(role: String, content: String)], for job: TranscriptionJob) async throws {
        // Use the folderPath already stored in the job
        guard let folderPath = job.folderPath else {
            throw PersistenceError.noStoragePath
        }
        
        let jobFolder = URL(fileURLWithPath: folderPath)
        let aiSummaryFolder = jobFolder.appendingPathComponent("AI Summary")
        try FileManager.default.createDirectory(at: aiSummaryFolder, withIntermediateDirectories: true)
        
        let chatPath = aiSummaryFolder.appendingPathComponent("chat.json")
        
        let chatData = messages.map { ["role": $0.role, "content": $0.content] }
        let jsonData = try JSONSerialization.data(withJSONObject: chatData, options: .prettyPrinted)
        try jsonData.write(to: chatPath)
        
        // Update database
        try await database.updateChatPath(job.id, chatPath: chatPath.path)
    }
    
    /// Find the job folder for a given job
    private func findJobFolder(for job: TranscriptionJob, in storagePath: URL) throws -> URL {
        let baseName = (job.audioFile.filename as NSString).deletingPathExtension
        
        // Find folder containing this filename
        let contents = try FileManager.default.contentsOfDirectory(at: storagePath, includingPropertiesForKeys: nil)
        
        for folder in contents where folder.hasDirectoryPath {
            if folder.lastPathComponent.contains(baseName) {
                return folder
            }
        }
        
        // If not found, create new folder
        let timestamp = DateFormatter.filenameSafe.string(from: Date())
        let jobFolderName = "\(timestamp)_\(baseName)"
        let jobFolder = storagePath.appendingPathComponent(jobFolderName)
        try FileManager.default.createDirectory(at: jobFolder, withIntermediateDirectories: true)
        return jobFolder
    }
    
    // MARK: - Folder Management
    
    /// Ensure storage path exists
    func ensureStoragePathExists() async throws {
        guard let storagePath = getStoragePath() else {
            throw PersistenceError.noStoragePath
        }
        
        if !FileManager.default.fileExists(atPath: storagePath.path) {
            try FileManager.default.createDirectory(at: storagePath, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let filenameSafe: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}

enum PersistenceError: LocalizedError {
    case noStoragePath
    case jobFolderNotFound
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .noStoragePath:
            return "No storage path configured. Please select a folder in Settings."
        case .jobFolderNotFound:
            return "Could not find job folder"
        case .saveFailed:
            return "Failed to save data"
        }
    }
}
