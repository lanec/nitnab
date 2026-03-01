//
//  AudioFileManager.swift
//  NitNab
//

import Foundation
import AVFoundation
import UniformTypeIdentifiers

actor AudioFileManager {
    
    static let shared = AudioFileManager()
    
    private init() {}
    
    // Supported audio file types
    static let supportedTypes: [UTType] = [
        .audio,
        .mp3,
        .wav,
        .aiff,
        UTType(filenameExtension: "m4a") ?? .audio,
        UTType(filenameExtension: "flac") ?? .audio,
        UTType(filenameExtension: "caf") ?? .audio
    ]
    
    /// Validates an audio file and creates an AudioFile model
    func validateAudioFile(at url: URL) async throws -> AudioFile {
        // Create AudioFile model (this validates the file and handles security scoped access)
        let audioFile = try await AudioFile(url: url)
        
        // Check if format is supported
        guard audioFile.isSupported else {
            throw AudioFileError.unsupportedFormat
        }
        
        return audioFile
    }
    
    /// Converts audio file to a format compatible with Speech framework if needed
    func prepareAudioForTranscription(audioFile: AudioFile) async throws -> URL {
        let url = audioFile.url
        
        // Access security scoped resource
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Check if the file is already in a compatible format
        if isCompatibleFormat(audioFile.format) {
            return url
        }
        
        // Convert to M4A (AAC) format
        return try await convertToCompatibleFormat(url: url)
    }
    
    private func isCompatibleFormat(_ format: String) -> Bool {
        // Speech framework works best with these formats
        let compatibleFormats = ["M4A", "WAV", "CAF"]
        return compatibleFormats.contains(format)
    }
    
    private func convertToCompatibleFormat(url: URL) async throws -> URL {
        let asset = AVAsset(url: url)
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioFileError.invalidFile
        }
        
        // Create temporary output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // Perform export
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            if let error = exportSession.error {
                throw error
            }
            throw AudioFileError.invalidFile
        }
        
        return outputURL
    }
    
    /// Extracts audio from video files
    func extractAudioFromVideo(url: URL) async throws -> URL {
        let asset = AVAsset(url: url)
        
        // Check if there's an audio track using modern async API
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AudioFileError.noAudioTrack
        }
        
        // Use the same conversion method
        return try await convertToCompatibleFormat(url: url)
    }
    
    /// Cleans up temporary files
    func cleanupTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: nil
            )
            
            for file in tempFiles where file.pathExtension == "m4a" {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("Failed to cleanup temporary files: \(error)")
        }
    }
}
