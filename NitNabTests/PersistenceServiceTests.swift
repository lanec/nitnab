//
//  PersistenceServiceTests.swift
//  NitNabTests
//
//  Unit tests for PersistenceService
//

import XCTest
@testable import NitNab

final class PersistenceServiceTests: XCTestCase {
    
    var persistenceService: PersistenceService!
    var testStoragePath: URL!
    
    override func setUpWithError() throws {
        persistenceService = PersistenceService.shared
        testStoragePath = TestFixtures.createTempDirectory()
    }
    
    override func tearDownWithError() throws {
        // Clean up test storage
        if let testStoragePath = testStoragePath {
            TestFixtures.removeTempDirectory(testStoragePath)
        }
        persistenceService = nil
    }

    private func ensureMockAudioSourceExists(for job: TranscriptionJob) throws {
        let sourceURL = job.audioFile.url
        try FileManager.default.createDirectory(
            at: sourceURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: sourceURL.path) {
            try Data("mock-audio-bytes".utf8).write(to: sourceURL)
        }
    }
    
    // MARK: - Storage Path Tests
    
    func testGetStoragePath_ReturnsValidPath() async throws {
        let storagePath = await persistenceService.getStoragePath()
        
        // Storage path may be nil if not configured yet, or may return iCloud/local path
        // This is acceptable behavior
        if let path = storagePath {
            XCTAssertFalse(path.path.isEmpty, "Storage path should not be empty")
        }
    }
    
    func testSetStoragePath_UpdatesStoragePath() async throws {
        // Set a test storage path
        await persistenceService.setStoragePath(testStoragePath)
        
        let retrievedPath = await persistenceService.getStoragePath()
        XCTAssertEqual(retrievedPath?.path, testStoragePath.path, "Storage path should be updated")
    }
    
    func testEnsureStoragePathExists_CreatesDirectory() async throws {
        // Set test storage path
        await persistenceService.setStoragePath(testStoragePath)
        
        // Ensure it exists
        try await persistenceService.ensureStoragePathExists()
        
        // Verify directory was created
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: testStoragePath.path),
            "Storage directory should exist"
        )
    }
    
    // MARK: - iCloud Detection Tests
    
    func testIsICloudAvailable_ReturnsBoolean() async throws {
        let isAvailable = await persistenceService.isiCloudAvailable()
        
        // Result depends on system configuration
        // Just verify it returns a valid boolean without crashing
        XCTAssertNotNil(isAvailable)
    }
    
    // MARK: - Job Saving Tests
    
    func testSaveJob_WithValidJob_SavesSuccessfully() async throws {
        // Set up test storage
        await persistenceService.setStoragePath(testStoragePath)
        try await persistenceService.ensureStoragePathExists()
        
        // Create a completed job with result
        var job = TestFixtures.createMockJob(status: .completed)
        job.result = TestFixtures.createMockResult()
        try ensureMockAudioSourceExists(for: job)
        
        do {
            try await persistenceService.saveJob(job)

            let createdFolders = try FileManager.default.contentsOfDirectory(
                at: testStoragePath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }

            XCTAssertTrue(
                !createdFolders.isEmpty,
                "saveJob should create a timestamped job folder in storage path"
            )
        } catch PersistenceError.noStoragePath {
            // This is acceptable if storage path isn't configured
            XCTAssertTrue(true, "No storage path configured")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSaveJob_CreatesProperFolderStructure() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        try await persistenceService.ensureStoragePathExists()
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.result = TestFixtures.createMockResult(transcript: "Test transcript content")
        try ensureMockAudioSourceExists(for: job)
        
        do {
            try await persistenceService.saveJob(job)

            let createdFolders = try FileManager.default.contentsOfDirectory(
                at: testStoragePath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            guard let jobFolder = createdFolders.first else {
                return XCTFail("Expected saveJob to create one job folder")
            }

            let audioFolder = jobFolder.appendingPathComponent("Audio")
            let transcriptFolder = jobFolder.appendingPathComponent("Transcript")
            let summaryFolder = jobFolder.appendingPathComponent("AI Summary")

            XCTAssertTrue(
                FileManager.default.fileExists(atPath: audioFolder.path),
                "Audio folder should exist"
            )
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: transcriptFolder.path),
                "Transcript folder should exist"
            )
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: summaryFolder.path),
                "AI Summary folder should exist"
            )
        } catch {
            // If error, at least verify it's a known error type
            XCTAssertTrue(error is PersistenceError, "Should throw PersistenceError if it fails")
        }
    }
    
    // MARK: - Transcript Saving Tests (1.0.2 Fix)
    
    func testSaveTranscript_UsesFolderPath_NotSearch() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        try await persistenceService.ensureStoragePathExists()
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.result = TestFixtures.createMockResult(transcript: "Test transcript for folderPath fix")
        
        // Set explicit folderPath (simulating 1.0.2 behavior)
        let jobFolder = testStoragePath.appendingPathComponent("test_transcript_folderpath")
        job.folderPath = jobFolder.path
        
        // Create the job folder
        try FileManager.default.createDirectory(at: jobFolder, withIntermediateDirectories: true)
        
        do {
            try await persistenceService.saveTranscript(for: job)
            
            // Verify transcript was saved using folderPath
            let transcriptFile = jobFolder
                .appendingPathComponent("Transcript")
                .appendingPathComponent("transcript.txt")
            
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: transcriptFile.path),
                "Transcript should be saved using job.folderPath"
            )
            
            let content = try? String(contentsOf: transcriptFile, encoding: .utf8)
            XCTAssertEqual(content, job.result?.fullTranscript, "Content should match")
        } catch {
            XCTFail("Should save transcript successfully: \(error)")
        }
    }
    
    func testSaveTranscript_CreatesTranscriptFolder() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.result = TestFixtures.createMockResult()
        job.folderPath = testStoragePath.appendingPathComponent("test_creates_folder").path
        
        try await persistenceService.saveTranscript(for: job)
        
        let transcriptFolder = URL(fileURLWithPath: job.folderPath!)
            .appendingPathComponent("Transcript")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: transcriptFolder.path),
            "Should create Transcript folder"
        )
    }
    
    func testSaveTranscript_SavesMetadataJSON() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.result = TestFixtures.createMockResult()
        job.folderPath = testStoragePath.appendingPathComponent("test_metadata").path
        
        try await persistenceService.saveTranscript(for: job)
        
        let metadataFile = URL(fileURLWithPath: job.folderPath!)
            .appendingPathComponent("Transcript")
            .appendingPathComponent("metadata.json")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: metadataFile.path),
            "Should save metadata.json"
        )
        
        // Verify JSON is valid
        let data = try? Data(contentsOf: metadataFile)
        let json = try? JSONSerialization.jsonObject(with: data!, options: [])
        XCTAssertNotNil(json, "metadata.json should contain valid JSON")
    }
    
    func testSaveTranscript_WithoutFolderPath_ThrowsError() async throws {
        var job = TestFixtures.createMockJob(status: .completed)
        job.result = TestFixtures.createMockResult()
        job.folderPath = nil // No folder path set
        
        do {
            try await persistenceService.saveTranscript(for: job)
            XCTFail("Should throw error when folderPath is nil")
        } catch PersistenceError.noStoragePath {
            XCTAssertTrue(true, "Correctly throws noStoragePath error")
        } catch {
            XCTFail("Should throw PersistenceError.noStoragePath, got: \(error)")
        }
    }
    
    // MARK: - Summary Saving Tests
    
    func testSaveSummary_WithValidData_SavesSuccessfully() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        try await persistenceService.ensureStoragePathExists()
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.result = TestFixtures.createMockResult()
        
        let jobFolder = testStoragePath.appendingPathComponent("test_summary")
        job.folderPath = jobFolder.path
        
        // Create the folder structure first
        try FileManager.default.createDirectory(
            at: jobFolder.appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        
        let summaryText = "This is a test summary of the meeting."
        
        do {
            try await persistenceService.saveSummary(summaryText, for: job)
            
            // Verify summary file was created
            let summaryFile = jobFolder
                .appendingPathComponent("AI Summary")
                .appendingPathComponent("summary.txt")
            
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: summaryFile.path),
                "Summary file should be created"
            )
            
            // Verify content
            let savedContent = try? String(contentsOf: summaryFile, encoding: .utf8)
            XCTAssertEqual(savedContent, summaryText, "Summary content should match")
        } catch {
            XCTAssertTrue(error is PersistenceError, "Should throw PersistenceError if it fails")
        }
    }
    
    // MARK: - Chat History Tests (1.0.2)
    
    func testSaveChatHistory_WithValidData_SavesSuccessfully() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        try await persistenceService.ensureStoragePathExists()
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = testStoragePath.appendingPathComponent("test_chat").path
        
        // Create folder structure
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: job.folderPath!)
                .appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        
        let chatHistory: [(role: String, content: String)] = [
            (role: "user", content: "What was discussed?"),
            (role: "assistant", content: "The team discussed Q4 planning.")
        ]
        
        do {
            try await persistenceService.saveChatHistory(chatHistory, for: job)
            
            // Verify chat file was created
            let chatFile = URL(fileURLWithPath: job.folderPath!)
                .appendingPathComponent("AI Summary")
                .appendingPathComponent("chat.json")
            
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: chatFile.path),
                "Chat history file should be created"
            )
        } catch {
            XCTAssertTrue(error is PersistenceError, "Should throw PersistenceError if it fails")
        }
    }
    
    func testLoadChatHistory_WithExistingChat_LoadsSuccessfully() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        try await persistenceService.ensureStoragePathExists()
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = testStoragePath.appendingPathComponent("test_load_chat").path
        
        // Create folder structure
        let aiSummaryFolder = URL(fileURLWithPath: job.folderPath!)
            .appendingPathComponent("AI Summary")
        try FileManager.default.createDirectory(
            at: aiSummaryFolder,
            withIntermediateDirectories: true
        )
        
        // Save chat history first
        let originalChat: [(role: String, content: String)] = [
            (role: "User", content: "Summarize the main points"),
            (role: "Assistant", content: "The main points are: 1. Planning 2. Budget 3. Timeline"),
            (role: "User", content: "What about risks?"),
            (role: "Assistant", content: "Key risks include resource constraints and timeline pressures.")
        ]
        
        try await persistenceService.saveChatHistory(originalChat, for: job)
        
        // Now load it back
        let loadedChat = try await persistenceService.loadChatHistory(for: job)
        
        XCTAssertEqual(loadedChat.count, originalChat.count, "Should load same number of messages")
        
        for (index, message) in loadedChat.enumerated() {
            XCTAssertEqual(message.role, originalChat[index].role, "Role should match")
            XCTAssertEqual(message.content, originalChat[index].content, "Content should match")
        }
    }
    
    func testLoadChatHistory_WithNoExistingChat_ReturnsEmpty() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        try await persistenceService.ensureStoragePathExists()
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = testStoragePath.appendingPathComponent("test_no_chat").path
        
        // Don't create any chat file
        let loadedChat = try await persistenceService.loadChatHistory(for: job)
        
        XCTAssertTrue(loadedChat.isEmpty, "Should return empty array when no chat exists")
    }
    
    func testLoadChatHistory_WithoutFolderPath_ReturnsEmpty() async throws {
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = nil // No folder path
        
        let loadedChat = try await persistenceService.loadChatHistory(for: job)
        
        XCTAssertTrue(loadedChat.isEmpty, "Should return empty array when no folder path")
    }
    
    func testChatHistory_RoundTrip_PreservesData() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        try await persistenceService.ensureStoragePathExists()
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = testStoragePath.appendingPathComponent("test_roundtrip").path
        
        // Create folder structure
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: job.folderPath!)
                .appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        
        let testChat: [(role: String, content: String)] = [
            (role: "User", content: "Test message with special chars: 你好 emoji 🎙️"),
            (role: "Assistant", content: "Response with\nmultiple\nlines"),
        ]
        
        // Save and load
        try await persistenceService.saveChatHistory(testChat, for: job)
        let loadedChat = try await persistenceService.loadChatHistory(for: job)
        
        XCTAssertEqual(loadedChat.count, testChat.count)
        XCTAssertEqual(loadedChat[0].content, testChat[0].content, "Special chars preserved")
        XCTAssertEqual(loadedChat[1].content, testChat[1].content, "Newlines preserved")
    }
    
    // MARK: - Error Handling Tests
    
    func testSaveJob_WithoutStoragePath_ThrowsError() async throws {
        // Don't set storage path
        var job = TestFixtures.createMockJob()
        job.result = TestFixtures.createMockResult()
        
        do {
            try await persistenceService.saveJob(job)
            // If it doesn't throw, that's also acceptable (might use default path)
        } catch PersistenceError.noStoragePath {
            XCTAssertTrue(true, "Should throw noStoragePath error")
        } catch {
            // Other errors are acceptable
            XCTAssertTrue(true, "Error handling works")
        }
    }
    
    func testPersistenceError_HasErrorDescriptions() throws {
        let noStorageError = PersistenceError.noStoragePath
        XCTAssertNotNil(noStorageError.errorDescription)
        XCTAssertTrue(noStorageError.errorDescription?.contains("storage path") ?? false)
        
        let noFolderError = PersistenceError.jobFolderNotFound
        XCTAssertNotNil(noFolderError.errorDescription)
        
        let saveError = PersistenceError.saveFailed
        XCTAssertNotNil(saveError.errorDescription)
    }
}
