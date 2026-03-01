//
//  TestHelpers.swift
//  NitNabTests
//
//  Created for test infrastructure
//

import Foundation
import XCTest
@testable import NitNab

// MARK: - Test Data Fixtures

struct TestFixtures {
    
    /// Creates a temporary directory for test storage
    static func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NitNabTests")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    /// Removes a test directory
    static func removeTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Creates a mock audio file for testing
    static func createMockAudioFile(filename: String = "test_audio.m4a") -> AudioFile {
        let mockDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NitNabTestsAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: mockDirectory, withIntermediateDirectories: true)
        let mockURL = mockDirectory.appendingPathComponent(filename)
        return AudioFile(
            url: mockURL,
            filename: filename,
            duration: 120.0, // 2 minutes
            fileSize: 1024 * 1024, // 1MB
            format: "M4A",
            sampleRate: 44100,
            channels: 2
        )
    }
    
    /// Creates a mock transcription job
    static func createMockJob(status: TranscriptionStatus = .pending) -> TranscriptionJob {
        let audioFile = createMockAudioFile()
        var job = TranscriptionJob(audioFile: audioFile)
        job.status = status
        return job
    }
    
    /// Creates a mock transcription result
    static func createMockResult(transcript: String = "This is a test transcript.") -> TranscriptionResult {
        return TranscriptionResult(
            fullTranscript: transcript,
            segments: [],
            language: "en-US",
            confidence: 0.95
        )
    }
}

// MARK: - Async Test Utilities

extension XCTestCase {
    /// Wait for async condition with timeout
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        condition: @escaping () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if await condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        
        XCTFail("Condition not met within timeout")
    }
}

// MARK: - Database Test Utilities

class TestDatabaseService {
    /// Creates a test database in a temporary location
    static func createTestDatabase() async throws -> URL {
        let tempDir = TestFixtures.createTempDirectory()
        let dbPath = tempDir.appendingPathComponent("test_nitnab.db")
        return dbPath
    }
    
    /// Cleans up test database
    static func cleanupTestDatabase(at url: URL) {
        let dbDir = url.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dbDir)
    }
}
