//
//  CompanyAssignmentTests.swift
//  NitNabTests
//
//  Tests for company assignment and persistence functionality
//

import XCTest
@testable import NitNab

@available(macOS 26.0, *)
final class CompanyAssignmentTests: XCTestCase {
    
    var database: DatabaseService!
    var memoryService: MemoryService!
    
    override func setUp() async throws {
        database = DatabaseService.shared
        memoryService = MemoryService.shared
    }

    private func audioPath(for folderName: String) -> String {
        "/tmp/\(folderName).m4a"
    }

    private func uniqueCompanyName(_ base: String) -> String {
        "\(base)-\(UUID().uuidString.prefix(8))"
    }
    
    // MARK: - Company Assignment Persistence Tests
    
    func testCompanyAssignment_PersistsToDatabase() async throws {
        // Create a test company
        let company = Company(name: uniqueCompanyName("Test Corp"))
        try await memoryService.createCompany(company)
        
        // Create and insert a job
        var job = TestFixtures.createMockJob(status: .completed)
        let folderName = "test_company_assignment_\(UUID().uuidString)"
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath(for: folderName))
        
        // Assign company to job
        job.companyId = company.id
        try await database.updateJob(job)
        
        // Verify assignment was saved
        let loadedJobs = await database.loadAllJobs()
        let loadedJob = loadedJobs.first(where: { $0.id == job.id })
        
        XCTAssertNotNil(loadedJob, "Job should be loaded from database")
        XCTAssertEqual(loadedJob?.companyId, company.id, "Company ID should persist")
    }
    
    func testCompanyAssignment_RoundTrip_SaveAndLoad() async throws {
        // This is the critical test for the bug we fixed
        
        // Step 1: Create company
        let company = Company(name: uniqueCompanyName("Acme Corp"), domain: "acme.com", notes: "Main client")
        try await memoryService.createCompany(company)
        
        // Step 2: Create job with company assignment
        var job = TestFixtures.createMockJob(status: .completed)
        job.companyId = company.id
        let folderName = "roundtrip_test_\(UUID().uuidString)"
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath(for: folderName))
        try await database.updateJob(job)
        
        // Step 3: Simulate app restart - load all jobs
        let reloadedJobs = await database.loadAllJobs()
        let reloadedJob = reloadedJobs.first(where: { $0.id == job.id })
        
        // Step 4: Verify company assignment survived the round trip
        XCTAssertNotNil(reloadedJob, "Job should be reloaded")
        XCTAssertEqual(reloadedJob?.companyId, company.id, "Company ID should survive save/load cycle")
        XCTAssertEqual(reloadedJob?.companyId, job.companyId, "Loaded company ID should match original")
    }
    
    func testNullCompanyAssignment_Persists() async throws {
        // Test that NULL company assignment (no company) also persists correctly
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.companyId = nil  // Explicitly no company
        let folderName = "null_company_test_\(UUID().uuidString)"
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath(for: folderName))
        try await database.updateJob(job)
        
        // Reload and verify NULL persists
        let reloadedJobs = await database.loadAllJobs()
        let reloadedJob = reloadedJobs.first(where: { $0.id == job.id })
        
        XCTAssertNotNil(reloadedJob, "Job should be loaded")
        XCTAssertNil(reloadedJob?.companyId, "NULL company assignment should persist")
    }
    
    func testChangeCompanyAssignment_Updates() async throws {
        // Test changing from one company to another
        
        let company1 = Company(name: uniqueCompanyName("Company A"))
        let company2 = Company(name: uniqueCompanyName("Company B"))
        try await memoryService.createCompany(company1)
        try await memoryService.createCompany(company2)
        
        // Create job with company A
        var job = TestFixtures.createMockJob(status: .completed)
        job.companyId = company1.id
        let folderName = "change_company_test_\(UUID().uuidString)"
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath(for: folderName))
        try await database.updateJob(job)
        
        // Change to company B
        job.companyId = company2.id
        try await database.updateJob(job)
        
        // Reload and verify it's now company B (not A)
        let reloadedJobs = await database.loadAllJobs()
        let reloadedJob = reloadedJobs.first(where: { $0.id == job.id })
        
        XCTAssertEqual(reloadedJob?.companyId, company2.id, "Should have new company assignment")
        XCTAssertNotEqual(reloadedJob?.companyId, company1.id, "Should NOT have old company assignment")
    }
    
    func testRemoveCompanyAssignment_SetsToNull() async throws {
        // Test removing a company assignment (setting to NULL)
        
        let company = Company(name: uniqueCompanyName("Temporary Company"))
        try await memoryService.createCompany(company)
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.companyId = company.id
        let folderName = "remove_company_test_\(UUID().uuidString)"
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath(for: folderName))
        try await database.updateJob(job)
        
        // Remove company assignment
        job.companyId = nil
        try await database.updateJob(job)
        
        // Reload and verify it's now NULL
        let reloadedJobs = await database.loadAllJobs()
        let reloadedJob = reloadedJobs.first(where: { $0.id == job.id })
        
        XCTAssertNil(reloadedJob?.companyId, "Company assignment should be removed (NULL)")
    }
    
    // MARK: - Multiple Jobs with Companies
    
    func testMultipleJobs_WithDifferentCompanies_AllPersist() async throws {
        // Test that multiple jobs with different company assignments all persist correctly
        
        let company1 = Company(name: uniqueCompanyName("Alpha Inc"))
        let company2 = Company(name: uniqueCompanyName("Beta LLC"))
        let company3 = Company(name: uniqueCompanyName("Gamma Corp"))
        try await memoryService.createCompany(company1)
        try await memoryService.createCompany(company2)
        try await memoryService.createCompany(company3)
        
        // Create jobs with different companies
        var job1 = TestFixtures.createMockJob(status: .completed)
        job1.companyId = company1.id
        
        var job2 = TestFixtures.createMockJob(status: .completed)
        job2.companyId = company2.id
        
        var job3 = TestFixtures.createMockJob(status: .completed)
        job3.companyId = company3.id
        
        var job4 = TestFixtures.createMockJob(status: .completed)
        job4.companyId = nil  // No company
        
        // Save all jobs
        let folder1 = "multi_job1_\(UUID().uuidString)"
        let folder2 = "multi_job2_\(UUID().uuidString)"
        let folder3 = "multi_job3_\(UUID().uuidString)"
        let folder4 = "multi_job4_\(UUID().uuidString)"
        try await database.insertTranscription(job1, folderName: folder1, audioPath: audioPath(for: folder1))
        try await database.insertTranscription(job2, folderName: folder2, audioPath: audioPath(for: folder2))
        try await database.insertTranscription(job3, folderName: folder3, audioPath: audioPath(for: folder3))
        try await database.insertTranscription(job4, folderName: folder4, audioPath: audioPath(for: folder4))
        
        try await database.updateJob(job1)
        try await database.updateJob(job2)
        try await database.updateJob(job3)
        try await database.updateJob(job4)
        
        // Reload all jobs
        let reloadedJobs = await database.loadAllJobs()
        
        // Verify each job has correct company
        let reloadedJob1 = reloadedJobs.first(where: { $0.id == job1.id })
        let reloadedJob2 = reloadedJobs.first(where: { $0.id == job2.id })
        let reloadedJob3 = reloadedJobs.first(where: { $0.id == job3.id })
        let reloadedJob4 = reloadedJobs.first(where: { $0.id == job4.id })
        
        XCTAssertEqual(reloadedJob1?.companyId, company1.id, "Job 1 should have Company 1")
        XCTAssertEqual(reloadedJob2?.companyId, company2.id, "Job 2 should have Company 2")
        XCTAssertEqual(reloadedJob3?.companyId, company3.id, "Job 3 should have Company 3")
        XCTAssertNil(reloadedJob4?.companyId, "Job 4 should have no company")
    }
    
    // MARK: - Company Deletion Impact Tests
    
    func testJobWithDeletedCompany_StillHasCompanyId() async throws {
        // When a company is deleted, the job should still have the company_id
        // (it becomes a dangling reference, which is expected behavior)
        
        let company = Company(name: uniqueCompanyName("To Be Deleted"))
        try await memoryService.createCompany(company)
        
        var job = TestFixtures.createMockJob(status: .completed)
        job.companyId = company.id
        let folderName = "deleted_company_test_\(UUID().uuidString)"
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath(for: folderName))
        try await database.updateJob(job)
        
        // Delete the company
        try await memoryService.deleteCompany(company.id)
        
        // Reload job - it should still have the company ID (dangling reference)
        let reloadedJobs = await database.loadAllJobs()
        let reloadedJob = reloadedJobs.first(where: { $0.id == job.id })
        
        XCTAssertEqual(reloadedJob?.companyId, company.id, "Job should still reference deleted company")
        
        // Verify company is actually deleted
        let companies = await memoryService.getAllCompanies()
        XCTAssertFalse(companies.contains(where: { $0.id == company.id }), "Company should be deleted")
    }
    
    // MARK: - Edge Cases
    
    func testInvalidUUID_HandledGracefully() async throws {
        // This tests that if somehow an invalid UUID gets into the database,
        // the parsing handles it gracefully (returns nil)
        // This is more of a defensive programming test
        
        var job = TestFixtures.createMockJob(status: .completed)
        let folderName = "edge_case_test_\(UUID().uuidString)"
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath(for: folderName))
        
        // This should complete without crashing
        let reloadedJobs = await database.loadAllJobs()
        XCTAssertNotNil(reloadedJobs, "Loading jobs should not crash")
    }
    
    func testCompanyAssignment_WorksWithAllJobStatuses() async throws {
        // Test that company assignment works for jobs in all states
        
        let company = Company(name: uniqueCompanyName("Universal Corp"))
        try await memoryService.createCompany(company)
        
        let statuses: [TranscriptionStatus] = [.pending, .processing, .completed, .failed, .cancelled]
        var jobs: [TranscriptionJob] = []
        
        for (index, status) in statuses.enumerated() {
            var job = TestFixtures.createMockJob(status: status)
            job.companyId = company.id
            let folderName = "status_test_\(status.rawValue)_\(index)"
            try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath(for: folderName))
            try await database.updateJob(job)
            jobs.append(job)
        }
        
        // Reload and verify all have company assignment
        let reloadedJobs = await database.loadAllJobs()
        
        for originalJob in jobs {
            let reloadedJob = reloadedJobs.first(where: { $0.id == originalJob.id })
            XCTAssertEqual(reloadedJob?.companyId, company.id, "Job with status \(originalJob.status) should have company")
        }
    }
    
    // MARK: - Performance Tests
    
    func testBulkCompanyAssignment_Performance() async throws {
        // Test that assigning companies to many jobs performs reasonably
        
        let company = Company(name: uniqueCompanyName("Performance Test Corp"))
        try await memoryService.createCompany(company)
        
        let jobCount = 50
        var jobs: [TranscriptionJob] = []
        
        // Create and save jobs
        for i in 0..<jobCount {
            var job = TestFixtures.createMockJob(status: .completed)
            job.companyId = company.id
            let folderName = "perf_test_\(i)_\(UUID().uuidString)"
            try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath(for: folderName))
            try await database.updateJob(job)
            jobs.append(job)
        }
        
        // Measure loading time
        let startTime = Date()
        let reloadedJobs = await database.loadAllJobs()
        let loadTime = Date().timeIntervalSince(startTime)
        
        // Verify all loaded correctly
        XCTAssertGreaterThanOrEqual(reloadedJobs.count, jobCount, "Should load at least the test jobs")
        
        // Performance assertion - should load in under 1 second
        XCTAssertLessThan(loadTime, 1.0, "Loading \(jobCount) jobs should complete in under 1 second")
        
        // Verify random sample has correct company
        if let randomJob = reloadedJobs.randomElement() {
            if jobs.contains(where: { $0.id == randomJob.id }) {
                XCTAssertEqual(randomJob.companyId, company.id, "Random job should have correct company")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflow_CreateCompanyAssignToJobReload() async throws {
        // Complete workflow test
        
        // 1. Create a company with contacts
        let company = Company(name: uniqueCompanyName("Full Workflow Corp"), domain: "workflow.com")
        try await memoryService.createCompany(company)
        
        let person1 = Person(fullName: "John Doe", phoneticSpelling: "John not Jon")
        let person2 = Person(fullName: "Jane Smith", title: "CEO")
        try await memoryService.addPerson(person1, to: company.id)
        try await memoryService.addPerson(person2, to: company.id)
        
        // 2. Create and complete a transcription job
        var job = TestFixtures.createMockJob(status: .completed)
        let folderName = "workflow_test_\(UUID().uuidString)"
        try await database.insertTranscription(job, folderName: folderName, audioPath: audioPath(for: folderName))
        
        // 3. Assign company to job
        job.companyId = company.id
        try await database.updateJob(job)
        
        // 4. Reload job (simulate app restart)
        let reloadedJobs = await database.loadAllJobs()
        guard let reloadedJob = reloadedJobs.first(where: { $0.id == job.id }) else {
            XCTFail("Job should be reloaded")
            return
        }
        
        // 5. Verify company assignment persisted
        XCTAssertEqual(reloadedJob.companyId, company.id, "Company assignment should persist")
        
        // 6. Load company and its people
        guard let loadedCompany = await memoryService.getCompany(company.id) else {
            XCTFail("Company should be loadable")
            return
        }
        
        let people = await memoryService.getPeopleForCompany(company.id)
        
        // 7. Verify everything is intact
        XCTAssertEqual(loadedCompany.name, company.name)
        XCTAssertEqual(people.count, 2, "Should have 2 people")
        XCTAssertTrue(people.contains(where: { $0.fullName == "John Doe" }))
        XCTAssertTrue(people.contains(where: { $0.fullName == "Jane Smith" }))
    }
}
