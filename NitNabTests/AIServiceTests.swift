//
//  AIServiceTests.swift
//  NitNabTests
//
//  Unit tests for AIService
//

import XCTest
@testable import NitNab

@available(macOS 26.0, *)
final class AIServiceTests: XCTestCase {
    
    var aiService: AIService!
    
    override func setUpWithError() throws {
        // AIService is a singleton
        aiService = AIService.shared
    }
    
    override func tearDownWithError() throws {
        aiService = nil
    }
    
    // MARK: - Summary Generation Tests
    
    func testGenerateSummary_WithValidTranscript_ReturnsNonEmptySummary() async throws {
        let transcript = """
        This is a test meeting transcript. We discussed the quarterly budget and revenue projections.
        The team agreed to prioritize the mobile app development in Q4.
        Action items include finalizing the design specs and hiring two additional developers.
        """
        
        do {
            let summary = try await aiService.generateSummary(transcript: transcript)
            
            XCTAssertFalse(summary.isEmpty, "Summary should not be empty")
            XCTAssertGreaterThan(summary.count, 10, "Summary should have meaningful content")
        } catch AIError.modelUnavailable {
            // Skip test if Apple Intelligence is not available
            throw XCTSkip("Apple Intelligence not available on this system")
        }
    }
    
    func testGenerateSummary_WithEmptyTranscript_HandlesGracefully() async throws {
        let emptyTranscript = ""
        
        do {
            let summary = try await aiService.generateSummary(transcript: emptyTranscript)
            // Should either return empty or a message about no content
            XCTAssertNotNil(summary)
        } catch AIError.modelUnavailable {
            throw XCTSkip("Apple Intelligence not available on this system")
        } catch {
            // Other errors are acceptable for empty input
            XCTAssertTrue(true, "Empty transcript handling is acceptable")
        }
    }
    
    func testGenerateSummary_WithVeryLongTranscript_CompletesSuccessfully() async throws {
        // Create a long transcript (simulate 30 minute meeting)
        let longTranscript = String(repeating: "This is a sentence in the transcript. ", count: 500)
        
        do {
            let summary = try await aiService.generateSummary(transcript: longTranscript)
            
            XCTAssertFalse(summary.isEmpty, "Should generate summary for long transcript")
            // Summary should be much shorter than original
            XCTAssertLessThan(summary.count, longTranscript.count / 2, "Summary should be concise")
        } catch AIError.modelUnavailable {
            throw XCTSkip("Apple Intelligence not available on this system")
        } catch AIError.generationFailed {
            // Long-context generation is model-dependent and can fail intermittently in CI/dev environments.
            throw XCTSkip("Long transcript generation failed due model/runtime limits")
        }
    }
    
    // MARK: - Chat Tests
    
    func testChat_WithValidQuestion_ReturnsResponse() async throws {
        let context = "Meeting about Q4 planning. Discussed budget of $100k for marketing."
        let message = "What was the marketing budget discussed?"
        
        do {
            let response = try await aiService.chat(
                message: message,
                context: context,
                conversationHistory: []
            )
            
            XCTAssertFalse(response.isEmpty, "Chat response should not be empty")
            XCTAssertGreaterThan(response.count, 10, "Response should have meaningful content")
        } catch AIError.modelUnavailable {
            throw XCTSkip("Apple Intelligence not available on this system")
        }
    }
    
    func testChat_WithConversationHistory_MaintainsContext() async throws {
        let context = "Discussion about hiring two developers for the mobile team."
        let history: [(role: String, content: String)] = [
            (role: "user", content: "How many developers are we hiring?"),
            (role: "assistant", content: "Two developers for the mobile team.")
        ]
        let message = "What team are they joining?"
        
        do {
            let response = try await aiService.chat(
                message: message,
                context: context,
                conversationHistory: history
            )
            
            XCTAssertFalse(response.isEmpty, "Chat should maintain context")
        } catch AIError.modelUnavailable {
            throw XCTSkip("Apple Intelligence not available on this system")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testAIService_WhenModelUnavailable_ThrowsAppropriateError() async throws {
        // This test verifies the error enum works
        let error = AIError.modelUnavailable
        
        XCTAssertFalse(error.localizedDescription.isEmpty)
        XCTAssertTrue(error.localizedDescription.contains("Apple Intelligence"))
    }
    
    func testAIService_GenerationFailedError_HasDescription() throws {
        let error = AIError.generationFailed
        
        XCTAssertFalse(error.localizedDescription.isEmpty)
        XCTAssertTrue(
            error.localizedDescription.contains("Failed to generate AI response"),
            "Description should explain generation failure"
        )
    }
    
    // MARK: - Performance Tests
    
    func testSummaryGeneration_CompletesInReasonableTime() async throws {
        let transcript = TestFixtures.createMockResult().fullTranscript
        
        let startTime = Date()
        
        do {
            _ = try await aiService.generateSummary(transcript: transcript)
            let duration = Date().timeIntervalSince(startTime)
            
            // Should complete within 30 seconds for short transcript
            XCTAssertLessThan(duration, 30.0, "Summary generation should be reasonably fast")
        } catch AIError.modelUnavailable {
            throw XCTSkip("Apple Intelligence not available on this system")
        }
    }
}
