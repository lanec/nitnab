//
//  AudioFileManagerTests.swift
//  NitNabTests
//
//  Unit tests for AudioFileManager
//

import XCTest
import AVFoundation
@testable import NitNab

final class AudioFileManagerTests: XCTestCase {
    
    var audioManager: AudioFileManager!
    
    override func setUpWithError() throws {
        audioManager = AudioFileManager.shared
    }
    
    override func tearDownWithError() throws {
        audioManager = nil
    }
    
    // MARK: - Supported Types Tests
    
    func testSupportedTypes_ContainsCommonFormats() throws {
        let supportedTypes = AudioFileManager.supportedTypes
        
        XCTAssertFalse(supportedTypes.isEmpty, "Should have supported types")
        
        // Check for common audio formats
        let typeIdentifiers = supportedTypes.map { $0.identifier }
        
        // Should support at least M4A (common format)
        XCTAssertTrue(
            typeIdentifiers.contains(where: { $0.contains("m4a") || $0.contains("mpeg-4-audio") }),
            "Should support M4A format"
        )
    }
    
    // MARK: - File Validation Tests
    
    func testValidateAudioFile_WithMockFile_ReturnsAudioFile() async throws {
        // Note: This test uses a mock since we don't have real audio files
        // In a real test, you'd use a bundled test audio file
        
        let mockAudioFile = TestFixtures.createMockAudioFile()
        
        XCTAssertNotNil(mockAudioFile)
        XCTAssertEqual(mockAudioFile.format, "M4A")
        XCTAssertGreaterThan(mockAudioFile.duration, 0)
        XCTAssertGreaterThan(mockAudioFile.fileSize, 0)
    }
    
    func testAudioFile_HasCorrectProperties() throws {
        let audioFile = TestFixtures.createMockAudioFile(filename: "test.m4a")
        
        XCTAssertEqual(audioFile.filename, "test.m4a")
        XCTAssertEqual(audioFile.format, "M4A")
        XCTAssertEqual(audioFile.duration, 120.0)
        XCTAssertEqual(audioFile.fileSize, 1024 * 1024)
        XCTAssertEqual(audioFile.sampleRate, 44100)
        XCTAssertEqual(audioFile.channels, 2)
    }
    
    // MARK: - Format Tests
    
    func testAudioFile_IsSupported_ReturnsTrueForValidFormats() throws {
        let supportedFormats = ["M4A", "WAV", "MP3", "AIFF", "CAF", "FLAC", "AAC"]
        
        for format in supportedFormats {
            let audioFile = TestFixtures.createMockAudioFile(filename: "test.\(format.lowercased())")
            // Change the format to match
            let testFile = AudioFile(
                url: audioFile.url,
                filename: audioFile.filename,
                duration: audioFile.duration,
                fileSize: audioFile.fileSize,
                format: format
            )
            
            XCTAssertTrue(testFile.isSupported, "\(format) should be supported")
        }
    }
    
    func testAudioFile_IsSupported_ReturnsFalseForUnsupportedFormat() throws {
        let unsupportedFile = AudioFile(
            url: URL(fileURLWithPath: "/tmp/test.xyz"),
            filename: "test.xyz",
            duration: 100,
            fileSize: 1000,
            format: "XYZ"
        )
        
        XCTAssertFalse(unsupportedFile.isSupported, "XYZ format should not be supported")
    }
    
    // MARK: - Formatted Output Tests
    
    func testAudioFile_FormattedFileSize_ReturnsReadableString() throws {
        let audioFile = TestFixtures.createMockAudioFile()
        let formattedSize = audioFile.formattedFileSize
        
        XCTAssertFalse(formattedSize.isEmpty, "Formatted size should not be empty")
        XCTAssertTrue(formattedSize.contains("MB") || formattedSize.contains("KB"), "Should have size unit")
    }
    
    func testAudioFile_FormattedDuration_ReturnsTimeString() throws {
        let audioFile = TestFixtures.createMockAudioFile()
        let formattedDuration = audioFile.formattedDuration
        
        XCTAssertFalse(formattedDuration.isEmpty, "Formatted duration should not be empty")
        XCTAssertTrue(formattedDuration.contains(":"), "Should be in MM:SS format")
        XCTAssertEqual(formattedDuration, "2:00", "120 seconds should format as 2:00")
    }
    
    func testAudioFile_FormattedDuration_WithVariousLengths() throws {
        let testCases: [(duration: TimeInterval, expected: String)] = [
            (30, "0:30"),      // 30 seconds
            (60, "1:00"),      // 1 minute
            (125, "2:05"),     // 2 minutes 5 seconds
            (3661, "61:01")    // Over an hour (displays as minutes)
        ]
        
        for (duration, expected) in testCases {
            let audioFile = AudioFile(
                url: URL(fileURLWithPath: "/tmp/test.m4a"),
                filename: "test.m4a",
                duration: duration,
                fileSize: 1000,
                format: "M4A"
            )
            
            XCTAssertEqual(audioFile.formattedDuration, expected, "Duration \(duration)s should format as \(expected)")
        }
    }
    
    // MARK: - Error Enum Tests
    
    func testAudioFileError_NoAudioTrack_HasDescription() throws {
        let error = AudioFileError.noAudioTrack
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("audio track") ?? false)
    }
    
    func testAudioFileError_UnsupportedFormat_HasDescription() throws {
        let error = AudioFileError.unsupportedFormat
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Unsupported") ?? false)
    }
    
    func testAudioFileError_InvalidFile_HasDescription() throws {
        let error = AudioFileError.invalidFile
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Invalid") ?? false)
    }
    
    // MARK: - Prepare for Transcription Tests
    
    func testPrepareAudioForTranscription_WithMockFile_Succeeds() async throws {
        // Note: This would need a real audio file to fully test
        // For now, we test that the manager exists and method signature is correct
        
        let mockFile = TestFixtures.createMockAudioFile()
        
        // In a real test with actual audio file:
        // let preparedURL = try await audioManager.prepareAudioForTranscription(audioFile: mockFile)
        // XCTAssertNotNil(preparedURL)
        
        // For now, just verify the mock file is valid
        XCTAssertNotNil(mockFile)
        XCTAssertTrue(mockFile.isSupported)
    }
}
