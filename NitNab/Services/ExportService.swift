//
//  ExportService.swift
//  NitNab
//

import Foundation

enum ExportFormat: String, CaseIterable {
    case txt = "Plain Text"
    case srt = "SRT Subtitles"
    case vtt = "WebVTT"
    case json = "JSON"
    case markdown = "Markdown"
    
    var fileExtension: String {
        switch self {
        case .txt: return "txt"
        case .srt: return "srt"
        case .vtt: return "vtt"
        case .json: return "json"
        case .markdown: return "md"
        }
    }
}

actor ExportService {
    
    static let shared = ExportService()
    
    private init() {}
    
    /// Export transcription result to specified format
    func export(result: TranscriptionResult, format: ExportFormat, to url: URL) async throws {
        let content: String
        
        switch format {
        case .txt:
            content = exportAsPlainText(result)
        case .srt:
            content = exportAsSRT(result)
        case .vtt:
            content = exportAsVTT(result)
        case .json:
            content = try exportAsJSON(result)
        case .markdown:
            content = exportAsMarkdown(result)
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Export Formats
    
    private func exportAsPlainText(_ result: TranscriptionResult) -> String {
        return result.fullTranscript
    }
    
    private func exportAsSRT(_ result: TranscriptionResult) -> String {
        var srt = ""
        
        for (index, segment) in result.segments.enumerated() {
            let startTime = formatSRTTime(segment.startTime)
            let endTime = formatSRTTime(segment.endTime)
            
            srt += "\(index + 1)\n"
            srt += "\(startTime) --> \(endTime)\n"
            srt += "\(segment.text)\n\n"
        }
        
        return srt
    }
    
    private func exportAsVTT(_ result: TranscriptionResult) -> String {
        var vtt = "WEBVTT\n\n"
        
        for segment in result.segments {
            let startTime = formatVTTTime(segment.startTime)
            let endTime = formatVTTTime(segment.endTime)
            
            vtt += "\(startTime) --> \(endTime)\n"
            vtt += "\(segment.text)\n\n"
        }
        
        return vtt
    }
    
    private func exportAsJSON(_ result: TranscriptionResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(result)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return jsonString
    }
    
    private func exportAsMarkdown(_ result: TranscriptionResult) -> String {
        var markdown = "# Transcription\n\n"
        markdown += "**Language:** \(result.language)\n"
        markdown += "**Date:** \(formatDate(result.createdAt))\n"
        markdown += "**Word Count:** \(result.wordCount)\n"
        markdown += "**Confidence:** \(String(format: "%.1f%%", result.confidence * 100))\n\n"
        markdown += "---\n\n"
        markdown += "## Full Transcript\n\n"
        markdown += result.fullTranscript
        markdown += "\n\n---\n\n"
        markdown += "## Segments\n\n"
        
        for segment in result.segments {
            markdown += "**\(segment.formattedTimeRange)**\n\n"
            markdown += "\(segment.text)\n\n"
        }
        
        return markdown
    }
    
    // MARK: - Helper Methods
    
    private func formatSRTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
    
    private func formatVTTTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum ExportError: LocalizedError {
    case encodingFailed
    case writeFailed
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode transcription data"
        case .writeFailed:
            return "Failed to write file"
        }
    }
}
