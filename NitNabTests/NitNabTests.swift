//
//  NitNabTests.swift
//  NitNabTests
//
//  Basic test infrastructure and sample tests
//

import XCTest
@testable import NitNab

final class NitNabTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // MARK: - Basic Infrastructure Tests
    
    func testTestInfrastructureIsWorking() throws {
        // Basic sanity check that tests can run
        XCTAssertTrue(true, "Test infrastructure is working")
    }
    
    func testCanCreateMockData() throws {
        let audioFile = TestFixtures.createMockAudioFile()
        XCTAssertNotNil(audioFile)
        XCTAssertEqual(audioFile.format, "M4A")
        XCTAssertEqual(audioFile.duration, 120.0)
    }
    
    func testCanCreateMockJob() throws {
        let job = TestFixtures.createMockJob()
        XCTAssertNotNil(job)
        XCTAssertEqual(job.status, .pending)
        XCTAssertEqual(job.progress, 0.0)
    }
    
    func testCanCreateMockTranscriptionResult() throws {
        let result = TestFixtures.createMockResult()
        XCTAssertNotNil(result)
        XCTAssertEqual(result.language, "en-US")
        XCTAssertGreaterThan(result.confidence, 0.0)
    }
    
    func testTempDirectoryCreation() throws {
        let tempDir = TestFixtures.createTempDirectory()
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
        
        // Cleanup
        TestFixtures.removeTempDirectory(tempDir)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path))
    }
}
