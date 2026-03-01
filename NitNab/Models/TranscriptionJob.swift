//
//  TranscriptionJob.swift
//  NitNab
//

import Foundation

enum TranscriptionStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
    case cancelled
}

struct TranscriptionJob: Identifiable, Codable {
    let id: UUID
    let audioFile: AudioFile
    var status: TranscriptionStatus
    var progress: Double
    var result: TranscriptionResult?
    var error: String?
    let createdAt: Date
    var completedAt: Date?
    var customName: String?
    var description: String?
    var folderPath: String?
    
    // NEW: Company and attendee tracking (Chunk 1)
    var companyId: UUID?           // Link to Company
    var attendeeIds: [UUID]?       // Array of Person IDs
    var detectedSpeakers: [String]? // AI-detected names from transcript
    var tags: [String]?            // AI-extracted topics
    var modifiedAt: Date?          // Last modification date
    var fileChecksum: String?      // MD5 checksum for duplicate detection
    
    init(audioFile: AudioFile) {
        self.id = UUID()
        self.audioFile = audioFile
        self.status = .pending
        self.progress = 0.0
        self.result = nil
        self.error = nil
        self.createdAt = Date()
        self.completedAt = nil
        self.customName = nil
        self.description = nil
        self.folderPath = nil
        self.companyId = nil
        self.attendeeIds = nil
        self.detectedSpeakers = nil
        self.tags = nil
        self.modifiedAt = nil
        self.fileChecksum = nil
    }
    
    // Full initializer for database reconstruction
    init(id: UUID, audioFile: AudioFile, status: TranscriptionStatus, progress: Double, result: TranscriptionResult?, error: String?, createdAt: Date, completedAt: Date?, customName: String?, description: String?, folderPath: String?, companyId: UUID? = nil, attendeeIds: [UUID]? = nil, detectedSpeakers: [String]? = nil, tags: [String]? = nil, modifiedAt: Date? = nil, fileChecksum: String? = nil) {
        self.id = id
        self.audioFile = audioFile
        self.status = status
        self.progress = progress
        self.result = result
        self.error = error
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.customName = customName
        self.description = description
        self.folderPath = folderPath
        self.companyId = companyId
        self.attendeeIds = attendeeIds
        self.detectedSpeakers = detectedSpeakers
        self.tags = tags
        self.modifiedAt = modifiedAt
        self.fileChecksum = fileChecksum
    }
    
    var displayName: String {
        return customName ?? audioFile.filename
    }
    
    var duration: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(createdAt)
    }
    
    var statusDescription: String {
        switch status {
        case .pending:
            return "Waiting to start..."
        case .processing:
            return "Transcribing... \(Int(progress * 100))%"
        case .completed:
            if let desc = description, !desc.isEmpty {
                return desc
            }
            return "Completed"
        case .failed:
            return "Failed: \(error ?? "Unknown error")"
        case .cancelled:
            return "Cancelled"
        }
    }
}
