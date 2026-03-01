//
//  TranscriptionService.swift
//  NitNab
//
//  Transcription engine using macOS 26 SpeechTranscriber/SpeechAnalyzer API
//

import Foundation
import Speech
import AVFoundation
import CoreMedia

@available(macOS 26.0, *)
actor TranscriptionService {

    static let shared = TranscriptionService()

    private var currentAnalyzer: SpeechAnalyzer?
    private var isCancelled = false

    private init() {}

    // MARK: - Availability

    /// Check if speech transcription is available on this device
    func isAvailable() -> Bool {
        SpeechTranscriber.isAvailable
    }

    /// Get available locales for transcription
    func getSupportedLocales() async -> [Locale] {
        Array(await SpeechTranscriber.supportedLocales)
    }

    // MARK: - Asset Management

    /// Ensure locale assets are downloaded and ready for transcription
    private func prepareLocale(_ locale: Locale) async throws {
        let supportedLocales = await SpeechTranscriber.supportedLocales
        guard supportedLocales.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else {
            throw TranscriptionError.unsupportedLocale(locale)
        }

        // Release previously reserved locales before reserving new one (Yap pattern)
        for reserved in await AssetInventory.reservedLocales {
            await AssetInventory.release(reservedLocale: reserved)
        }
        try await AssetInventory.reserve(locale: locale)

        // Download assets if not already installed
        let installedLocales = await SpeechTranscriber.installedLocales
        if installedLocales.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
            return
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }

    // MARK: - Transcription

    /// Transcribe an audio file using SpeechTranscriber
    /// - Parameters:
    ///   - audioURL: URL of the audio file to transcribe
    ///   - locale: Target locale for recognition
    ///   - customVocabulary: Vocabulary terms (kept for API compat; used by AI post-processing, not the recognizer)
    ///   - progressHandler: Called with progress 0.0-1.0 based on real audio position
    func transcribe(
        audioURL: URL,
        locale: Locale = Locale(identifier: "en-US"),
        customVocabulary: [String] = [],
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws -> TranscriptionResult {

        // Guard against concurrent transcriptions
        guard currentAnalyzer == nil else {
            throw TranscriptionError.transcriptionFailed(
                NSError(domain: "TranscriptionService", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "A transcription is already in progress"])
            )
        }

        // Reset cancellation flag
        isCancelled = false

        // Access security scoped resource
        let hasAccess = audioURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                audioURL.stopAccessingSecurityScopedResource()
            }
        }

        // Prepare locale and download assets if needed
        try await prepareLocale(locale)

        // Create transcriber with word-level timing
        // reportingOptions: [] means only final results (no volatile/partial)
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )

        // Get audio duration for progress calculation
        let audioFile = try AVAudioFile(forReading: audioURL)
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        guard duration > 0 else {
            throw TranscriptionError.audioProcessingFailed
        }

        // Create analyzer and start
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        currentAnalyzer = analyzer
        try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)

        // Consume results via native AsyncSequence — no callbacks, no continuation races
        var allResults: [AttributedString] = []
        var resultCount = 0

        for try await result in transcriber.results {
            if isCancelled {
                await currentAnalyzer?.cancelAndFinishNow()
                currentAnalyzer = nil
                throw TranscriptionError.cancelled
            }

            allResults.append(result.text)
            resultCount += 1

            // Derive progress from the last audio time range in this result's attributed string
            if let timeRange = result.text.runs.last?.audioTimeRange {
                let endSeconds = CMTimeGetSeconds(CMTimeRangeGetEnd(timeRange))
                let progress = min(endSeconds / duration, 1.0)
                progressHandler(progress)
            }
        }

        currentAnalyzer = nil

        guard !allResults.isEmpty else {
            throw TranscriptionError.transcriptionFailed(
                NSError(domain: "SpeechTranscriber", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "No speech detected in audio file"])
            )
        }

        progressHandler(1.0)

        return TranscriptionResult(
            attributedResults: allResults,
            language: locale.identifier
        )
    }

    /// Cancel ongoing transcription
    func cancelTranscription() async {
        isCancelled = true
        await currentAnalyzer?.cancelAndFinishNow()
        currentAnalyzer = nil
    }
}

enum TranscriptionError: LocalizedError {
    case unsupportedLocale(Locale)
    case audioProcessingFailed
    case transcriptionFailed(Error)
    case cancelled
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .unsupportedLocale(let locale):
            return "Locale '\(locale.identifier)' is not supported for transcription"
        case .audioProcessingFailed:
            return "Failed to process audio file"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .cancelled:
            return "Transcription was cancelled"
        case .notAvailable:
            return "Speech transcription is not available on this device"
        }
    }
}
