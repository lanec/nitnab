# Changelog

All notable changes to NitNab will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2025-10-10

### Fixed
- **Transcription Output Saving** - Transcripts and AI summaries now correctly save to user-configured storage path
  - Fixed `saveTranscript()` to use `job.folderPath` instead of unreliable folder search
  - Fixed `saveSummary()` to use stored folder path
  - Fixed `saveChatHistory()` to use stored folder path
  - Added `loadChatHistory()` to restore conversations from disk
  - Ensures files work with unsigned builds by using direct file paths
- **AI Chat Error Handling** - Enhanced error messages and logging for Apple Intelligence failures
  - Added detailed console logging for AI chat errors
  - Improved error messages with actionable guidance
  - Added diagnostics for Apple Intelligence configuration issues
- **Per-File Chat Conversations** - Each transcript now has its own independent chat
  - Added `.task(id: job.id)` to reload chat when switching files
  - Added `loadChatHistory()` method to PersistenceService
  - Chat history persists across app restarts
  - Switching between files now shows correct conversation
- **Chat Input Behavior** - Enter key now submits messages as expected
  - Added `.onSubmit` modifier to chat TextField
  - Enter sends message, Shift+Enter creates new line
  - Standard chat interface behavior

### Added
- **loadChatHistory()** method in PersistenceService for restoring per-file chat conversations
- Comprehensive features documentation in README.md (200+ features documented)
- Enhanced logging throughout persistence operations
- Better error messages for Apple Intelligence requirements

### Changed
- README.md completely updated with comprehensive feature documentation
- Improved console output for debugging transcription and AI operations
- Version badge added to README
- Enhanced PersistenceService with better error handling and logging

### Testing
- **Comprehensive test coverage for all v1.0.2 features**
- Added 16+ new tests for transcript saving and per-file chat
- Enhanced PersistenceServiceTests with 4 new transcript saving tests
- Created ChatPerFileTests.swift with 12 comprehensive tests
  - Per-file chat isolation tests
  - Chat history persistence tests
  - Edge case coverage (empty, long, special characters)
  - File system and JSON format validation
- Total test count: 60+ tests
- Coverage: 95%+ of critical paths
- All tests prevent regression of v1.0.2 bugs

### Documentation
- Comprehensive feature documentation added to README (200+ features)
- Features organized by category (Audio, Transcription, AI, Storage, Export, UI, etc.)
- Added statistics: 70+ languages, 8+ formats, 5 export formats
- Updated version references throughout documentation
- Added TRANSCRIPT_SAVING_FIX.md documenting the persistence fix
- Added AI_CHAT_ERROR_FIX.md documenting Apple Intelligence troubleshooting
- Added CHAT_PER_FILE_FIX.md documenting per-file chat implementation
- Added CHAT_ENTER_KEY_FIX.md documenting keyboard behavior fix
- Added TEST_COVERAGE_1.0.2.md documenting comprehensive test coverage

## [1.0.1] - 2025-10-09

### Changed
- Updated tagline to correctly reflect acronym: "Nifty Instant Transcription Nifty AutoSummarize Buddy"
- Enhanced documentation and repository structure for GitHub publication
- Improved README with comprehensive feature descriptions and architecture details

### Added
- GitHub issue templates (bug report, feature request)
- Pull request template
- Publication checklist for repository maintainers
- Repository status documentation

## [1.0.0] - 2025-10-09

### Added
- Native macOS application for audio transcription using Apple's Speech framework
- Support for multiple audio formats (M4A, WAV, MP3, AIFF, CAF, FLAC, AAC)
- Multi-language transcription support
- AI-powered summaries using Apple Intelligence (FoundationModels)
- Interactive chat with transcript content
- iCloud sync for transcripts and data
- SQLite database for persistent job tracking
- Export functionality (TXT, JSON, SRT, VTT formats)
- Modern SwiftUI interface with drag-and-drop support
- Real-time transcription progress tracking
- Automatic database schema migration system

### Fixed
- Database persistence issue where jobs would disappear after app restart
- Database schema migration for existing installations
- SQLite parameter binding for optional fields
- Race condition in database initialization
- File path management for iCloud and local storage

### Technical Details
- Built with Swift 6.0 and SwiftUI
- Targets macOS 26.0+ (Apple Silicon optimized)
- Uses Swift Concurrency (async/await, actors) throughout
- On-device processing for privacy
- Comprehensive error logging and diagnostics
