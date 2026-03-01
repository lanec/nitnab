//
//  TranscriptionResult.swift
//  NitNab
//

import Foundation
import Speech
import CoreMedia

struct TranscriptionResult: Codable {
    let id: UUID
    let fullTranscript: String
    let segments: [TranscriptionSegment]
    let language: String
    let confidence: Double
    let createdAt: Date
    
    init(fullTranscript: String, segments: [TranscriptionSegment], language: String, confidence: Double = 1.0) {
        self.id = UUID()
        self.fullTranscript = fullTranscript
        self.segments = segments
        self.language = language
        self.confidence = confidence
        self.createdAt = Date()
    }
    
    var wordCount: Int {
        fullTranscript.split(separator: " ").count
    }
    
    var characterCount: Int {
        fullTranscript.count
    }
}

// MARK: - SpeechTranscriber Convenience Initializer

@available(macOS 26.0, *)
extension TranscriptionResult {
    /// Create from SpeechTranscriber AttributedString results with word-level timing
    init(attributedResults: [AttributedString], language: String) {
        var fullText = ""
        var segments: [TranscriptionSegment] = []

        for attributed in attributedResults {
            for run in attributed.runs {
                let text = String(attributed[run.range].characters)
                fullText += text
                if let timeRange = run.audioTimeRange {
                    segments.append(TranscriptionSegment(
                        text: text,
                        startTime: CMTimeGetSeconds(timeRange.start),
                        endTime: CMTimeGetSeconds(CMTimeRangeGetEnd(timeRange)),
                        confidence: 1.0
                    ))
                }
            }
        }

        self.init(
            fullTranscript: fullText,
            segments: segments,
            language: language,
            confidence: 1.0
        )
    }
}

struct TranscriptionSegment: Identifiable, Codable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double
    
    init(text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Double = 1.0) {
        self.id = UUID()
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
    
    var duration: TimeInterval {
        endTime - startTime
    }
    
    var formattedTimeRange: String {
        let startFormatted = formatTime(startTime)
        let endFormatted = formatTime(endTime)
        return "\(startFormatted) → \(endFormatted)"
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%d:%02d.%03d", minutes, seconds, milliseconds)
        }
    }
}
