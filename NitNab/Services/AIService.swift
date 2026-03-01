//
//  AIService.swift
//  NitNab
//

import Foundation
import FoundationModels

@available(macOS 26.0, *)
actor AIService {

    static let shared = AIService()

    private init() {}

    // MARK: - Session Factory

    /// Create a fresh session per operation to avoid unbounded context accumulation
    private func createSession(instructions: String) -> LanguageModelSession {
        LanguageModelSession {
            instructions
        }
    }

    // MARK: - Context Building (Chunk 5 - Task 5.1)

    /// Build AI context from user's personal profile and memories
    func buildAIContext() async -> String {
        let contextString = await MemoryService.shared.buildAIContextString()
        return contextString
    }

    /// Generate a summary of the transcript with personal context
    func generateSummary(transcript: String) async throws -> String {
        let session = createSession(instructions: """
            You are a helpful assistant that creates concise, clear summaries of transcripts.
            Focus on the main points, key takeaways, and action items.
            Keep summaries brief but informative.
            """)

        let userContext = await buildAIContext()

        let prompt: String
        if !userContext.isEmpty {
            prompt = """
            Context about the user: \(userContext)

            Please provide a concise summary of the following transcript in 3-5 sentences. Focus on the main points and key takeaways:

            \(transcript)
            """
        } else {
            prompt = """
            Please provide a concise summary of the following transcript in 3-5 sentences. Focus on the main points and key takeaways:

            \(transcript)
            """
        }

        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            throw AIError.generationFailed
        }
    }

    /// Chat with the AI about the transcript
    func chat(message: String, context: String, conversationHistory: [(role: String, content: String)]) async throws -> String {
        let session = createSession(instructions: """
            You are a helpful assistant that answers questions about transcripts.
            Provide clear, accurate responses based on the transcript content.
            """)

        let userContext = await buildAIContext()

        var prompt = ""
        if !userContext.isEmpty {
            prompt += "About the user: \(userContext)\n\n"
        }

        prompt += "Context: Here is a transcript of a conversation:\n\n\(context)\n\n"

        // Include conversation history so the model has context of prior exchanges
        if !conversationHistory.isEmpty {
            prompt += "Previous conversation:\n"
            for entry in conversationHistory {
                let role = entry.role == "user" ? "User" : "Assistant"
                prompt += "\(role): \(entry.content)\n"
            }
            prompt += "\n"
        }

        prompt += "User question: \(message)\n\nPlease provide a helpful response based on the transcript above."

        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            throw AIError.generationFailed
        }
    }

    // MARK: - Name Extraction (Chunk 5 - Task 5.2)

    /// Extract person names from transcript using AI
    func extractNames(transcript: String, knownPeople: [Person] = []) async throws -> [String] {
        let session = createSession(instructions: "You extract person names from transcripts. Return ONLY comma-separated names.")

        let knownNames = knownPeople.map { $0.fullName }.joined(separator: ", ")
        let userContext = await buildAIContext()

        var prompt = ""
        if !userContext.isEmpty {
            prompt += "Context: \(userContext)\n\n"
        }

        if !knownNames.isEmpty {
            prompt += "Known people: \(knownNames)\n\n"
        }

        prompt += """
        Extract all person names mentioned in this transcript. Return ONLY a comma-separated list of names.

        Transcript:
        \(transcript)

        Names:
        """

        do {
            let response = try await session.respond(to: prompt)
            let names = response.content.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return names
        } catch {
            throw AIError.generationFailed
        }
    }

    // MARK: - Smart Filename (Chunk 5 - Task 5.3)

    func suggestFileName(transcript: String, speakers: [String] = []) async throws -> String {
        let session = createSession(instructions: "You suggest concise filenames for transcripts. Return ONLY the filename.")

        let speakerList = speakers.isEmpty ? "" : "Speakers: \(speakers.joined(separator: ", "))\n\n"

        let prompt = """
        \(speakerList)Based on the following transcript, suggest a concise, descriptive filename (2-5 words, separated by underscores, no file extension).

        Focus on the main topic or purpose of the meeting/conversation.

        Transcript excerpt:
        \(String(transcript.prefix(1000)))

        Return ONLY the filename, nothing else.
        """

        do {
            let response = try await session.respond(to: prompt)
            var filename = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Clean up the filename
            filename = filename.replacingOccurrences(of: " ", with: "_")
            filename = filename.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "", options: .regularExpression)
            filename = filename.prefix(60).description // Limit length

            return filename.isEmpty ? "Meeting" : filename
        } catch {
            throw AIError.generationFailed
        }
    }

    // MARK: - Topic Extraction (Chunk 5 - Task 5.4)

    /// Extract main topics/themes from transcript for tag cloud
    func extractTopics(transcript: String, maxTopics: Int = 10) async throws -> [String] {
        let session = createSession(instructions: "You extract key topics from transcripts. Return topic keywords, one per line.")

        let prompt = """
        Extract the \(maxTopics) most important topics or themes from this transcript.

        Return only the topic keywords/phrases, one per line, without explanations or numbering.
        Use 1-3 words per topic.

        Transcript:
        \(transcript)
        """

        do {
            let response = try await session.respond(to: prompt)
            let topics = response.content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .map { $0.replacingOccurrences(of: "^[0-9]+\\.\\s*", with: "", options: .regularExpression) }
                .map { $0.replacingOccurrences(of: "^-\\s*", with: "", options: .regularExpression) }
                .filter { !$0.isEmpty && $0.count > 1 }
                .prefix(maxTopics)

            return Array(topics)
        } catch {
            throw AIError.generationFailed
        }
    }

    // MARK: - Name Correction

    /// Correct misheard names in transcript using company's known people
    func correctMisheardNames(transcript: String, knownPeople: [Person]) async throws -> String {
        let session = createSession(instructions: "You correct misheard names in speech-to-text transcriptions. Return ONLY the corrected transcript.")

        // Build list of correct names with phonetic info
        let peopleList = knownPeople.map { person in
            var info = "- \(person.fullName)"
            if let preferred = person.preferredName {
                info += " (goes by \(preferred))"
            }
            if let phonetic = person.phoneticSpelling {
                info += " [sounds like: \(phonetic)]"
            }
            return info
        }.joined(separator: "\n")

        let prompt = """
        You are correcting a speech-to-text transcription. The transcription may have misheard some names.

        CORRECT NAMES (from company records):
        \(peopleList)

        TASK: Review the transcript and correct any misheard names based on the correct names list above.
        For example:
        - "Wayne" might actually be "Lane"
        - "Megan" might actually be "Megan" (already correct)
        - "John" might be "Jon" or "Johan"

        IMPORTANT:
        - ONLY fix names that are clearly wrong based on phonetic similarity
        - Keep the EXACT same text otherwise - same punctuation, capitalization, everything
        - If you're not confident a name is wrong, leave it unchanged
        - Return ONLY the corrected transcript, no explanations

        ORIGINAL TRANSCRIPT:
        \(transcript)

        CORRECTED TRANSCRIPT:
        """

        do {
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw AIError.generationFailed
        }
    }
}

enum AIError: Error {
    case modelUnavailable
    case generationFailed
    case notConfigured

    var localizedDescription: String {
        switch self {
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device. Requires macOS 15.1+ (Sequoia) with Apple Silicon and Apple Intelligence enabled in System Settings."
        case .generationFailed:
            return "Failed to generate AI response. Please ensure Apple Intelligence is enabled in System Settings > Apple Intelligence & Siri, and that you're signed in with your Apple ID."
        case .notConfigured:
            return "Apple Intelligence is not configured. Please enable it in System Settings > Apple Intelligence & Siri."
        }
    }
}
