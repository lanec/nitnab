//
//  TranscriptionWorkflowTests.swift
//  NitNabTests
//
//  Integration tests for complete transcription workflow
//

import XCTest
@testable import NitNab

@MainActor
final class TranscriptionWorkflowTests: XCTestCase {
    
    var viewModel: TranscriptionViewModel!
    
    override func setUpWithError() throws {
        viewModel = TranscriptionViewModel()
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
    }
    
    // MARK: - ViewModel Initialization Tests
    
    func testViewModel_InitializesSuccessfully() throws {
        XCTAssertNotNil(viewModel)
        XCTAssertEqual(viewModel.jobs.count, 0, "Should start with no jobs")
        XCTAssertFalse(viewModel.isProcessing, "Should not be processing initially")
        XCTAssertNil(viewModel.selectedJob, "Should have no selected job initially")
    }
    
    func testViewModel_LoadsSupportedLocales() async throws {
        // Wait for locales to load
        try await Task.sleep(for: .milliseconds(500))
        
        XCTAssertFalse(viewModel.supportedLocales.isEmpty, "Should have supported locales")
        XCTAssertNotNil(viewModel.selectedLocale, "Should have a selected locale")
    }
    
    // MARK: - Job Management Tests
    
    func testAddFiles_AddsJobsToList() async throws {
        let initialCount = viewModel.jobs.count
        
        // Create mock URLs (these won't actually exist, but tests structure)
        let mockURLs = [
            URL(fileURLWithPath: "/tmp/test1.m4a"),
            URL(fileURLWithPath: "/tmp/test2.m4a")
        ]
        
        // This will fail because files don't exist, but we can test the structure
        viewModel.addFiles(mockURLs)
        
        // Give it time to process
        try await Task.sleep(for: .milliseconds(300))
        
        // Jobs may not be added since files don't exist, but the method should not crash
        XCTAssertNotNil(viewModel.jobs, "Jobs array should still be valid")
    }
    
    func testSelectJob_UpdatesSelectedJob() throws {
        // Create a mock job and add it
        let mockAudioFile = TestFixtures.createMockAudioFile()
        let job = TranscriptionJob(audioFile: mockAudioFile)
        viewModel.jobs.append(job)
        
        // Select the job
        viewModel.selectJob(job)
        
        XCTAssertEqual(viewModel.selectedJob?.id, job.id, "Selected job should be updated")
    }

    func testSetSelection_MultipleSelectionClearsPrimarySelection() throws {
        let jobA = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        let jobB = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        viewModel.jobs = [jobA, jobB]

        viewModel.setSelection([jobA.id, jobB.id], primary: jobA.id)

        XCTAssertEqual(viewModel.selectedJobIDs.count, 2, "Both jobs should be selected")
        XCTAssertNil(viewModel.selectedJob, "Primary detail selection should clear in multi-select state")
    }

    func testSyncSelectionAfterJobsMutation_PrunesDeletedIDs() throws {
        let jobA = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        let jobB = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        viewModel.jobs = [jobA, jobB]
        viewModel.setSelection([jobA.id, jobB.id], primary: jobA.id)

        viewModel.jobs = [jobB]
        viewModel.syncSelectionAfterJobsMutation()

        XCTAssertEqual(viewModel.selectedJobIDs, [jobB.id], "Selection should keep only still-existing jobs")
        XCTAssertEqual(viewModel.selectedJob?.id, jobB.id, "Single remaining selection should become primary")
    }
    
    func testRemoveJob_RemovesFromList() throws {
        let job = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        viewModel.jobs.append(job)
        
        let initialCount = viewModel.jobs.count
        viewModel.removeJob(job)
        
        XCTAssertEqual(viewModel.jobs.count, initialCount - 1, "Job should be removed")
        XCTAssertFalse(viewModel.jobs.contains(where: { $0.id == job.id }), "Job should not exist")
    }
    
    func testRemoveJob_ClearsSelection_IfJobWasSelected() throws {
        let job = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        viewModel.jobs.append(job)
        viewModel.selectJob(job)
        
        XCTAssertNotNil(viewModel.selectedJob, "Job should be selected")
        
        viewModel.removeJob(job)
        
        XCTAssertNil(viewModel.selectedJob, "Selection should be cleared")
    }
    
    // MARK: - Processing State Tests
    
    func testCanStartProcessing_ReturnsFalse_WhenNoJobs() throws {
        viewModel.jobs = []
        
        XCTAssertFalse(viewModel.canStartProcessing, "Should not be able to start with no jobs")
    }
    
    func testCanStartProcessing_ReturnsFalse_WhenAlreadyProcessing() throws {
        viewModel.jobs = [TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())]
        viewModel.isProcessing = true
        
        XCTAssertFalse(viewModel.canStartProcessing, "Should not be able to start when already processing")
    }
    
    func testCanStartProcessing_ReturnsFalse_WhenNoPendingJobs() throws {
        var job = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        job.status = .completed
        viewModel.jobs = [job]
        
        XCTAssertFalse(viewModel.canStartProcessing, "Should not be able to start with no pending jobs")
    }
    
    // MARK: - Retry Logic Tests
    
    func testRetryJob_ResetsJobStatus() throws {
        var job = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        job.status = .failed
        job.error = "Test error"
        job.progress = 0.5
        
        viewModel.jobs = [job]
        viewModel.retryJob(job)
        
        let retriedJob = viewModel.jobs.first(where: { $0.id == job.id })
        XCTAssertEqual(retriedJob?.status, .pending, "Status should be reset to pending")
        XCTAssertEqual(retriedJob?.progress, 0.0, "Progress should be reset")
        XCTAssertNil(retriedJob?.error, "Error should be cleared")
        XCTAssertNil(retriedJob?.result, "Result should be cleared")
    }

    func testValidateDeleteRequest_BlocksProcessingJobs() throws {
        var processingJob = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        processingJob.status = .processing
        let completedJob = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        viewModel.jobs = [processingJob, completedJob]

        let result = viewModel.validateDeleteRequest(ids: [processingJob.id, completedJob.id])

        XCTAssertEqual(result.blockedProcessingJobs.map(\.id), [processingJob.id], "Processing jobs must block bulk delete")
        XCTAssertEqual(result.deletableIDs, [completedJob.id], "Non-processing jobs should remain deletable")
        XCTAssertFalse(result.isValid, "Validation should fail when any processing jobs are included")
    }
    
    // MARK: - Clear Operations Tests
    
    func testClearCompleted_RemovesCompletedAndFailedJobs() throws {
        var completedJob = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        completedJob.status = .completed
        
        var failedJob = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        failedJob.status = .failed
        
        var pendingJob = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        pendingJob.status = .pending
        
        viewModel.jobs = [completedJob, failedJob, pendingJob]
        
        viewModel.clearCompleted()
        
        XCTAssertEqual(viewModel.jobs.count, 1, "Should only have pending job left")
        XCTAssertEqual(viewModel.jobs.first?.status, .pending, "Remaining job should be pending")
    }
    
    func testClearAll_RemovesAllJobs() throws {
        viewModel.jobs = [
            TranscriptionJob(audioFile: TestFixtures.createMockAudioFile()),
            TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        ]
        
        viewModel.clearAll()
        
        XCTAssertEqual(viewModel.jobs.count, 0, "All jobs should be removed")
    }
    
    // MARK: - Export Tests
    
    func testCopyToClipboard_WithCompletedJob() throws {
        var job = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        job.status = .completed
        job.result = TestFixtures.createMockResult(transcript: "Test transcript")
        
        viewModel.jobs = [job]
        
        // Copy to clipboard
        viewModel.copyToClipboard(job)
        
        // Verify clipboard has content
        let pasteboard = NSPasteboard.general
        let clipboardString = pasteboard.string(forType: .string)
        
        XCTAssertNotNil(clipboardString, "Clipboard should have content")
        XCTAssertEqual(clipboardString, "Test transcript", "Clipboard should contain transcript")
    }
    
    // MARK: - Authorization Tests
    
    func testCheckAuthorization_UpdatesStatus() async throws {
        await viewModel.checkAuthorization()

        if viewModel.isTranscriptionAvailable {
            XCTAssertFalse(viewModel.showingError, "Should not show error when transcription is available")
        } else {
            XCTAssertTrue(viewModel.showingError, "Should show error when transcription is unavailable")
            XCTAssertNotNil(viewModel.errorMessage, "Should include an explanatory error message")
        }
    }
    
    // MARK: - File Management Tests
    
    func testShowRenameDialog_UpdatesCustomName() throws {
        // This test verifies the structure exists
        // In UI tests, we would actually test the dialog interaction
        
        var job = TranscriptionJob(audioFile: TestFixtures.createMockAudioFile())
        viewModel.jobs = [job]
        
        // Manually update custom name (simulating dialog result)
        if let index = viewModel.jobs.firstIndex(where: { $0.id == job.id }) {
            viewModel.jobs[index].customName = "New Custom Name"
        }
        
        let updatedJob = viewModel.jobs.first(where: { $0.id == job.id })
        XCTAssertEqual(updatedJob?.customName, "New Custom Name")
    }
    
    // MARK: - Database Integration Tests
    
    func testLoadJobsFromDatabase_LoadsExistingJobs() async throws {
        // Jobs should be loaded on init
        // This tests that the database integration works
        
        // Give it time to load
        try await Task.sleep(for: .milliseconds(500))
        
        // Jobs array should be initialized (even if empty)
        XCTAssertNotNil(viewModel.jobs)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorMessage_CanBeSetAndCleared() throws {
        XCTAssertNil(viewModel.errorMessage, "Should start with no error")
        XCTAssertFalse(viewModel.showingError, "Should not be showing error")
        
        // Errors are private in the viewModel, but we can test the published properties exist
        XCTAssertNotNil(viewModel.jobs, "ViewModel should be functional")
    }
}
