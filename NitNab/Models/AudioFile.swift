//
//  AudioFile.swift
//  NitNab
//

import Foundation
import AVFoundation

struct AudioFile: Identifiable, Codable {
    let id: UUID
    let url: URL
    let filename: String
    let fileSize: Int64
    let duration: TimeInterval
    let format: String
    let sampleRate: Double
    let channels: Int
    
    init(url: URL) async throws {
        self.id = UUID()
        self.url = url
        self.filename = url.lastPathComponent
        
        // Try to access the file with security scoped resource
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Get file size - use resource values which work better with sandboxing
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        self.fileSize = Int64(resourceValues.fileSize ?? 0)
        
        // Get audio properties using modern async APIs
        let asset = AVAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            throw AudioFileError.noAudioTrack
        }
        
        self.duration = try await asset.load(.duration).seconds
        self.format = url.pathExtension.uppercased()
        
        // Get format descriptions
        if let formatDescriptions = try await audioTrack.load(.formatDescriptions) as? [CMAudioFormatDescription],
           let formatDescription = formatDescriptions.first {
            let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
            self.sampleRate = basicDescription?.pointee.mSampleRate ?? 0
            self.channels = Int(basicDescription?.pointee.mChannelsPerFrame ?? 0)
        } else {
            self.sampleRate = 0
            self.channels = 0
        }
    }
    
    // Initializer for database reconstruction
    init(url: URL, filename: String, duration: TimeInterval, fileSize: Int64, format: String, sampleRate: Double = 44100, channels: Int = 2) {
        self.id = UUID()
        self.url = url
        self.filename = filename
        self.duration = duration
        self.fileSize = fileSize
        self.format = format
        self.sampleRate = sampleRate
        self.channels = channels
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var isSupported: Bool {
        let supportedFormats = ["M4A", "WAV", "MP3", "AIFF", "CAF", "FLAC", "AAC"]
        return supportedFormats.contains(format)
    }
}

enum AudioFileError: LocalizedError {
    case noAudioTrack
    case unsupportedFormat
    case invalidFile
    
    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "No audio track found in file"
        case .unsupportedFormat:
            return "Unsupported audio format"
        case .invalidFile:
            return "Invalid or corrupted audio file"
        }
    }
}
