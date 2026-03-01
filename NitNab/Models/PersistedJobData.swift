//
//  PersistedJobData.swift
//  NitNab
//

import Foundation

/// Represents the complete persisted data for a transcription job
struct PersistedJobData: Codable, Identifiable {
    let id: UUID
    let audioFileName: String
    let createdAt: Date
    let language: String
    let transcript: String?
    let summary: String?
    let chatMessages: [ChatMessage]
    let metadata: JobMetadata
    
    struct ChatMessage: Codable, Identifiable {
        let id: UUID
        let role: String // "User" or "Assistant"
        let content: String
        let timestamp: Date
        
        init(id: UUID = UUID(), role: String, content: String, timestamp: Date = Date()) {
            self.id = id
            self.role = role
            self.content = content
            self.timestamp = timestamp
        }
    }
    
    struct JobMetadata: Codable {
        let audioDuration: TimeInterval
        let audioFileSize: Int64
        let confidence: Double?
        let wordCount: Int?
        let characterCount: Int?
        let completedAt: Date?
    }
    
    init(from job: TranscriptionJob, summary: String? = nil, chatMessages: [ChatMessage] = []) {
        self.id = job.id
        self.audioFileName = job.audioFile.filename
        self.createdAt = job.createdAt
        self.language = job.audioFile.url.absoluteString // Store locale identifier
        self.transcript = job.result?.fullTranscript
        self.summary = summary
        self.chatMessages = chatMessages
        self.metadata = JobMetadata(
            audioDuration: job.audioFile.duration,
            audioFileSize: job.audioFile.fileSize,
            confidence: job.result?.confidence,
            wordCount: job.result?.wordCount,
            characterCount: job.result?.characterCount,
            completedAt: job.completedAt
        )
    }
}
