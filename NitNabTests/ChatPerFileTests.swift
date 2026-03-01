//
//  ChatPerFileTests.swift
//  NitNabTests
//
//  Tests for per-file chat functionality (v1.0.2)
//

import XCTest
@testable import NitNab

@available(macOS 26.0, *)
final class ChatPerFileTests: XCTestCase {
    
    var persistenceService: PersistenceService!
    var testStoragePath: URL!
    
    override func setUpWithError() throws {
        persistenceService = PersistenceService.shared
        testStoragePath = TestFixtures.createTempDirectory()
    }
    
    override func tearDownWithError() throws {
        if let testStoragePath = testStoragePath {
            TestFixtures.removeTempDirectory(testStoragePath)
        }
        persistenceService = nil
    }
    
    // MARK: - Per-File Chat Isolation Tests
    
    func testChatHistory_IsolatedPerFile() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        
        // Create two different jobs
        var job1 = TestFixtures.createMockJob(status: .completed)
        job1.folderPath = testStoragePath.appendingPathComponent("job1").path
        
        var job2 = TestFixtures.createMockJob(status: .completed)
        job2.folderPath = testStoragePath.appendingPathComponent("job2").path
        
        // Create folders
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: job1.folderPath!).appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: job2.folderPath!).appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        
        // Save different chat histories
        let chat1: [(role: String, content: String)] = [
            (role: "User", content: "Question about job 1"),
            (role: "Assistant", content: "Answer about job 1")
        ]
        
        let chat2: [(role: String, content: String)] = [
            (role: "User", content: "Question about job 2"),
            (role: "Assistant", content: "Answer about job 2")
        ]
        
        try await persistenceService.saveChatHistory(chat1, for: job1)
        try await persistenceService.saveChatHistory(chat2, for: job2)
        
        // Load and verify they're different
        let loaded1 = try await persistenceService.loadChatHistory(for: job1)
        let loaded2 = try await persistenceService.loadChatHistory(for: job2)
        
        XCTAssertEqual(loaded1.count, 2, "Job 1 should have 2 messages")
        XCTAssertEqual(loaded2.count, 2, "Job 2 should have 2 messages")
        
        XCTAssertEqual(loaded1[0].content, "Question about job 1")
        XCTAssertEqual(loaded2[0].content, "Question about job 2")
        
        XCTAssertNotEqual(loaded1[0].content, loaded2[0].content, "Chats should be different")
    }
    
    func testChatHistory_PreservesAfterUpdate() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = testStoragePath.appendingPathComponent("update_test").path
        
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: job.folderPath!).appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        
        // Save initial chat
        let initialChat: [(role: String, content: String)] = [
            (role: "User", content: "First message")
        ]
        try await persistenceService.saveChatHistory(initialChat, for: job)
        
        // Load and verify
        var loaded = try await persistenceService.loadChatHistory(for: job)
        XCTAssertEqual(loaded.count, 1)
        
        // Add more messages
        let updatedChat: [(role: String, content: String)] = [
            (role: "User", content: "First message"),
            (role: "Assistant", content: "First response"),
            (role: "User", content: "Second message")
        ]
        try await persistenceService.saveChatHistory(updatedChat, for: job)
        
        // Load and verify all messages present
        loaded = try await persistenceService.loadChatHistory(for: job)
        XCTAssertEqual(loaded.count, 3, "Should have all 3 messages")
    }
    
    // MARK: - Chat History Persistence Tests
    
    func testChatHistory_PersistsAcrossLoads() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = testStoragePath.appendingPathComponent("persist_test").path
        
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: job.folderPath!).appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        
        let chat: [(role: String, content: String)] = [
            (role: "User", content: "Persistent message"),
            (role: "Assistant", content: "Persistent response")
        ]
        
        // Save
        try await persistenceService.saveChatHistory(chat, for: job)
        
        // Load multiple times to verify persistence
        for _ in 0..<3 {
            let loaded = try await persistenceService.loadChatHistory(for: job)
            XCTAssertEqual(loaded.count, 2, "Should persist across multiple loads")
            XCTAssertEqual(loaded[0].content, "Persistent message")
        }
    }
    
    // MARK: - Edge Cases
    
    func testChatHistory_EmptyArray() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = testStoragePath.appendingPathComponent("empty_test").path
        
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: job.folderPath!).appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        
        let emptyChat: [(role: String, content: String)] = []
        
        // Should be able to save empty array
        try await persistenceService.saveChatHistory(emptyChat, for: job)
        
        // Should load as empty
        let loaded = try await persistenceService.loadChatHistory(for: job)
        XCTAssertTrue(loaded.isEmpty, "Should handle empty chat history")
    }
    
    func testChatHistory_LongConversation() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = testStoragePath.appendingPathComponent("long_test").path
        
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: job.folderPath!).appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        
        // Create a long conversation (50 messages)
        var longChat: [(role: String, content: String)] = []
        for i in 0..<50 {
            longChat.append((role: i % 2 == 0 ? "User" : "Assistant", content: "Message \(i)"))
        }
        
        try await persistenceService.saveChatHistory(longChat, for: job)
        
        let loaded = try await persistenceService.loadChatHistory(for: job)
        XCTAssertEqual(loaded.count, 50, "Should handle long conversations")
    }
    
    func testChatHistory_SpecialCharacters() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = testStoragePath.appendingPathComponent("special_chars").path
        
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: job.folderPath!).appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        
        let specialChat: [(role: String, content: String)] = [
            (role: "User", content: "Test with \"quotes\" and 'apostrophes'"),
            (role: "Assistant", content: "Unicode: 你好 🎙️ ñ é"),
            (role: "User", content: "Backslash \\ and newline \n test"),
            (role: "Assistant", content: """
                Multi-line
                response
                here
                """)
        ]
        
        try await persistenceService.saveChatHistory(specialChat, for: job)
        let loaded = try await persistenceService.loadChatHistory(for: job)
        
        XCTAssertEqual(loaded.count, 4)
        XCTAssertTrue(loaded[1].content.contains("你好"))
        XCTAssertTrue(loaded[1].content.contains("Unicode:"))
        XCTAssertTrue(loaded[3].content.contains("Multi-line"))
    }
    
    // MARK: - File System Tests
    
    func testChatHistory_CreatesCorrectFilePath() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = testStoragePath.appendingPathComponent("filepath_test").path
        
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: job.folderPath!).appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        
        let chat: [(role: String, content: String)] = [
            (role: "User", content: "Test")
        ]
        
        try await persistenceService.saveChatHistory(chat, for: job)
        
        // Verify file exists at correct path
        let expectedPath = URL(fileURLWithPath: job.folderPath!)
            .appendingPathComponent("AI Summary")
            .appendingPathComponent("chat.json")
        
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: expectedPath.path),
            "chat.json should be in AI Summary folder"
        )
    }
    
    func testChatHistory_JSONFormat() async throws {
        await persistenceService.setStoragePath(testStoragePath)
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.folderPath = testStoragePath.appendingPathComponent("json_test").path
        
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: job.folderPath!).appendingPathComponent("AI Summary"),
            withIntermediateDirectories: true
        )
        
        let chat: [(role: String, content: String)] = [
            (role: "User", content: "Test message"),
            (role: "Assistant", content: "Test response")
        ]
        
        try await persistenceService.saveChatHistory(chat, for: job)
        
        // Read and verify JSON structure
        let chatFile = URL(fileURLWithPath: job.folderPath!)
            .appendingPathComponent("AI Summary")
            .appendingPathComponent("chat.json")
        
        let data = try Data(contentsOf: chatFile)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: String]]
        
        XCTAssertNotNil(json, "Should be valid JSON array")
        XCTAssertEqual(json?.count, 2, "Should have 2 messages")
        XCTAssertEqual(json?[0]["role"], "User")
        XCTAssertEqual(json?[0]["content"], "Test message")
    }
}
