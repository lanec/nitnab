//
//  DatabaseServiceTests.swift
//  NitNabTests
//
//  Unit tests for DatabaseService
//

import XCTest
import SQLite3
@testable import NitNab

final class DatabaseServiceTests: XCTestCase {
    
    var testDBPath: URL!
    
    override func setUpWithError() throws {
        // Create a temporary database for each test
        testDBPath = TestFixtures.createTempDirectory().appendingPathComponent("test.db")
    }
    
    override func tearDownWithError() throws {
        // Clean up test database
        if let testDBPath = testDBPath {
            TestFixtures.removeTempDirectory(testDBPath.deletingLastPathComponent())
        }
    }
    
    // MARK: - Database Initialization Tests
    
    func testDatabaseInitialization() async throws {
        // Test that database can be initialized
        // Note: DatabaseService is a singleton, so we test that it exists
        let database = DatabaseService.shared
        XCTAssertNotNil(database)
    }
    
    // MARK: - Job Insertion Tests
    
    func testInsertTranscription() async throws {
        let database = DatabaseService.shared
        let job = TestFixtures.createMockJob(status: .pending)
        let folderName = "2025-10-10_test_audio"
        let audioPath = "/tmp/test_audio.m4a"
        
        // Insert the job
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath)
        
        // Verify it was inserted by loading all jobs
        let jobs = await database.loadAllJobs()
        XCTAssertTrue(jobs.contains(where: { $0.id == job.id }), "Inserted job should be loadable")
    }
    
    // MARK: - Job Update Tests
    
    func testUpdateJob() async throws {
        let database = DatabaseService.shared
        var job = TestFixtures.createMockJob(status: .pending)
        let folderName = "2025-10-10_test_audio_update"
        let audioPath = "/tmp/test_audio_update.m4a"
        
        // Insert the job
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath)
        
        // Update the job
        job.status = .completed
        job.progress = 1.0
        job.completedAt = Date()
        job.result = TestFixtures.createMockResult()
        
        try await database.updateJob(job)
        
        // Load and verify
        let jobs = await database.loadAllJobs()
        let updatedJob = jobs.first(where: { $0.id == job.id })
        
        XCTAssertNotNil(updatedJob)
        XCTAssertEqual(updatedJob?.status, .completed)
        XCTAssertEqual(updatedJob?.progress, 1.0)
        XCTAssertNotNil(updatedJob?.result)
    }
    
    // MARK: - Job Loading Tests
    
    func testLoadAllJobs() async throws {
        let database = DatabaseService.shared
        
        // Insert multiple jobs
        let job1 = TestFixtures.createMockJob(status: .pending)
        let job2 = TestFixtures.createMockJob(status: .completed)
        
        try await database.insertTranscription(job1, folderName: "folder1", audioPath: "/tmp/audio1.m4a")
        try await database.insertTranscription(job2, folderName: "folder2", audioPath: "/tmp/audio2.m4a")
        
        // Load all jobs
        let jobs = await database.loadAllJobs()
        
        XCTAssertGreaterThanOrEqual(jobs.count, 2, "Should load at least 2 jobs")
    }
    
    // MARK: - Summary and Chat Path Tests
    
    func testUpdateSummaryPath() async throws {
        let database = DatabaseService.shared
        let job = TestFixtures.createMockJob(status: .completed)
        let folderName = "2025-10-10_test_summary"
        let audioPath = "/tmp/test_summary.m4a"
        
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath)
        
        // Update summary path
        let summaryPath = "/tmp/test_summary.txt"
        try await database.updateSummaryPath(job.id, summaryPath: summaryPath)
        
        // Verify through transcription record
        let record = await database.getTranscription(id: job.id)
        XCTAssertEqual(record?.summaryPath, summaryPath)
    }
    
    func testUpdateChatPath() async throws {
        let database = DatabaseService.shared
        let job = TestFixtures.createMockJob(status: .completed)
        let folderName = "2025-10-10_test_chat"
        let audioPath = "/tmp/test_chat.m4a"
        
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath)
        
        // Update chat path
        let chatPath = "/tmp/test_chat.json"
        try await database.updateChatPath(job.id, chatPath: chatPath)
        
        // Verify through transcription record
        let record = await database.getTranscription(id: job.id)
        XCTAssertEqual(record?.chatPath, chatPath)
    }
    
    // MARK: - Transcription Record Tests
    
    func testGetAllTranscriptions() async throws {
        let database = DatabaseService.shared
        
        let job = TestFixtures.createMockJob(status: .completed)
        try await database.insertTranscription(job, folderName: "test_folder", audioPath: "/tmp/test.m4a")
        
        let records = await database.getAllTranscriptions()
        XCTAssertGreaterThanOrEqual(records.count, 1, "Should have at least one transcription record")
    }
    
    func testGetTranscriptionById() async throws {
        let database = DatabaseService.shared
        let job = TestFixtures.createMockJob(status: .completed)
        let folderName = "2025-10-10_test_get_by_id"
        let audioPath = "/tmp/test_get_by_id.m4a"
        
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath)
        
        let record = await database.getTranscription(id: job.id)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.id, job.id)
        XCTAssertEqual(record?.folderName, folderName)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentOperations() async throws {
        let database = DatabaseService.shared
        var insertedJobIds = Set<UUID>()
        
        // Perform multiple concurrent operations (actor should handle this safely)
        await withTaskGroup(of: UUID?.self) { group in
            for i in 0..<5 {
                group.addTask {
                    let job = TestFixtures.createMockJob()
                    try? await database.insertTranscription(
                        job,
                        folderName: "concurrent_\(i)",
                        audioPath: "/tmp/concurrent_\(i).m4a"
                    )
                    return job.id
                }
            }

            for await id in group {
                if let id {
                    insertedJobIds.insert(id)
                }
            }
        }
        
        // Verify all jobs were inserted
        let jobs = await database.loadAllJobs()
        let concurrentJobs = jobs.filter { insertedJobIds.contains($0.id) }
        
        XCTAssertGreaterThanOrEqual(concurrentJobs.count, 5, "All concurrent inserts should succeed")
    }

    func testInsertPersistsFileChecksum() async throws {
        let database = DatabaseService.shared
        var job = TestFixtures.createMockJob(status: .pending)
        job.fileChecksum = "abc123checksum"

        try await database.insertTranscription(
            job,
            folderName: "checksum_test_\(UUID().uuidString)",
            audioPath: "/tmp/checksum_test.m4a"
        )

        let loaded = await database.loadAllJobs().first(where: { $0.id == job.id })
        XCTAssertEqual(loaded?.fileChecksum, "abc123checksum")
    }

    func testUpdateTranscriptionWithResultPersistsTranscriptPath() async throws {
        let database = DatabaseService.shared
        var job = TestFixtures.createMockJob(status: .completed)
        job.result = TestFixtures.createMockResult(transcript: "Path persistence test")

        try await database.insertTranscription(
            job,
            folderName: "transcript_path_test_\(UUID().uuidString)",
            audioPath: "/tmp/transcript_path_test.m4a"
        )

        let transcriptPath = "/tmp/transcript_path_test.txt"
        try await database.updateTranscriptionWithResult(job, transcriptPath: transcriptPath)

        let record = await database.getTranscription(id: job.id)
        XCTAssertEqual(record?.transcriptPath, transcriptPath)
    }
    
    // MARK: - Custom Name and Description Tests
    
    func testJobWithCustomName() async throws {
        let database = DatabaseService.shared
        var job = TestFixtures.createMockJob()
        job.customName = "Custom Meeting Name"
        job.description = "Important client meeting"
        
        try await database.insertTranscription(job, folderName: "custom_test", audioPath: "/tmp/custom.m4a")
        
        let jobs = await database.loadAllJobs()
        let loadedJob = jobs.first(where: { $0.id == job.id })
        
        XCTAssertEqual(loadedJob?.customName, "Custom Meeting Name")
        XCTAssertEqual(loadedJob?.description, "Important client meeting")
    }
}
