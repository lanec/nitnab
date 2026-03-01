# NitNab 🎙️

[![Swift Version](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2026.0+-blue.svg)](https://developer.apple.com/macos/)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon-blue.svg)](https://developer.apple.com/silicon/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.4-brightgreen.svg)](https://github.com/lanec/nitnab/releases)

**Nifty Instant Transcription Nifty AutoSummarize Buddy**

A powerful, privacy-focused native macOS application for transcribing audio files using Apple's cutting-edge Speech framework and Apple Intelligence. Built for macOS 26+ with Swift 6.0 and optimized for Apple Silicon.

> **200+ features** • **70+ languages** • **8+ audio formats** • **5 export formats** • **100% privacy-first**

## 📋 Table of Contents

- [Features](#-features)
- [Screenshots](#-screenshots)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Usage](#-usage)
- [Architecture](#-architecture)
- [Development](#-development)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ Features

### 🎵 Audio File Management

**File Import**
- Browse Files button for native macOS file picker
- Drag & Drop support with visual feedback
- Multi-file selection for batch processing
- Automatic duplicate detection using MD5 checksums
- File validation (format, duration, quality)

**Supported Audio Formats**
- M4A, WAV, MP3, AIFF, CAF, FLAC, AAC, ALAC
- 8+ audio formats with automatic format detection
- Support for compressed and lossless codecs

**File Organization**
- Automatic timestamped folder creation: `YYYY-MM-DD_HH-MM-SS_filename/`
- Structured storage: Audio/, Transcript/, AI Summary/ subfolders
- SQLite database tracking for all files and metadata
- MD5 checksums prevent duplicate processing

---

### 🎙️ Transcription Engine

**Core Transcription**
- Apple Speech Framework (SFSpeechRecognizer API)
- 100% on-device processing (privacy-first)
- High accuracy leveraging Apple's latest speech recognition
- Real-time progress with time-based estimation
- Automatic error handling and recovery
- Status tracking: Pending, Processing, Completed, Failed

**Multi-Language Support**
- 70+ languages supported
- Language selector dropdown
- Remembers preferred language
- Per-file language selection

**Batch Processing**
- Sequential file processing
- Automatic queue management
- Error recovery (continues after failures)
- Cancel anytime without losing progress

**Quality Metrics**
- Word count tracking
- Character count tracking
- Confidence scores
- Duration tracking
- Timestamp support for subtitles

---

### 🤖 Apple Intelligence Features

**AI Summaries**
- One-click summary generation
- Context-aware using FoundationModels
- Regenerate for different perspectives
- Copy to clipboard instantly
- Auto-saved to `AI Summary/summary.txt`
- Persistent across app restarts

**Interactive AI Chat**
- **Per-file conversations** - Each file has independent chat
- Chat history saved per file in `AI Summary/chat.json`
- Context persistence when switching files
- Natural language queries
- Draft emails based on transcript
- Extract action items automatically
- Summarize on demand
- Copy individual responses
- **Keyboard shortcuts**: Enter to send, Shift+Enter for new line

**AI Context & Memory**
- User profile (name, role, company)
- Company context for files
- Custom vocabulary per company
- Name correction using context
- Smart pre-populated suggestions

---

### 💾 Data Persistence & Storage

**Automatic Saving** (Enabled by Default)
- Audio files → `Audio/` folder
- Transcripts → `Transcript/transcript.txt`
- Metadata → `Transcript/metadata.json`
- AI summaries → `AI Summary/summary.txt`
- Chat history → `AI Summary/chat.json`

**Storage Options**
- **iCloud Drive**: Automatic sync across devices
- **Custom Folder**: Store anywhere on Mac or external drives
- Ubiquitous container: `iCloud.$(CFBundleIdentifier)`
- Works with unsigned builds via direct file paths

**Database Management**
- SQLite database (`nitnab.db`)
- Automatic schema migration
- Job metadata tracking
- MD5 checksums for duplicates
- Referential integrity

**Folder Structure**
```
NitNab/
├── nitnab.db
└── 2025-10-10_16-30-00_filename/
    ├── Audio/filename.m4a
    ├── Transcript/
    │   ├── transcript.txt
    │   └── metadata.json
    └── AI Summary/
        ├── summary.txt
        └── chat.json
```

---

### 📤 Export & Sharing

**Export Formats**
- **Plain Text (.txt)** - Clean transcript
- **Markdown (.md)** - Formatted document
- **SRT (.srt)** - Subtitle format with timestamps
- **WebVTT (.vtt)** - Web video text tracks
- **JSON (.json)** - Structured data with metadata

**Export Features**
- Single file or batch export
- Format selection per export
- Optional metadata inclusion
- Automatic file naming with timestamps

**Copy & Paste**
- One-click copy full transcript
- Copy AI summaries
- Copy individual chat responses
- Select and copy text portions
- Native clipboard integration

---

### 🎨 User Interface

**View Modes**
- **Standard Mode**: Simple file list with drop zone
- **Advanced Mode**: Power user features (search, tags, sorting)
- Instant mode switching
- Persistent mode preference

**Three-Tab Interface**
- **Transcript Tab**: Full transcription text
- **Summary Tab**: AI-generated summaries
- **Chat Tab**: Interactive AI conversation

**File List Features**
- Visual selection with blue border
- Status icons for job states
- Real-time progress bars
- Inline error messages (no popups!)
- File info: name, duration, format, date
- Right-click context menu

**Drop Zone**
- Visual drag & drop feedback
- Large Browse Files button
- Supported format list
- Clear instructions
- Helpful empty state

---

### 🔍 Advanced Mode Features

**Search & Filter**
- Full-text search (filename, transcript, description)
- Real-time filtering as you type
- Result count display
- Case-insensitive matching
- Quick clear button

**Tag System**
- Custom tags for organization
- Tag cloud with counts
- Click to filter by tag
- Multi-tag support per file
- Visual tag display

**Sorting Options**
- Date Added (newest first)
- Date Modified
- Date Completed
- Alphabetical (A-Z)
- Persistent sort preference

**Company Management**
- Associate files with companies
- Company picker interface
- AI uses company context
- Custom vocabulary per company
- People database integration

---

### ⚙️ Settings & Configuration

**General Settings**
- Default transcription language
- Always open in Advanced Mode
- Auto-start transcription after adding files
- Default export format

**Persistence Settings**
- Auto-persist toggle
- Storage location (iCloud or custom)
- iCloud availability status
- Folder picker
- Current path display

**Memory & Context**
- User profile management
- Company management
- People/contacts database
- Custom vocabulary
- Context building for AI

---

### 🔐 Privacy & Security

**Privacy-First Design**
- 100% on-device processing
- No cloud services (except optional iCloud Drive for file sync)
- No external API calls
- No data collection or analytics
- No account required
- Works completely offline

**Data Security**
- Security-scoped resource handling
- macOS sandbox compliance
- Encrypted iCloud sync
- Local SQLite database
- MD5 file integrity checks

**Permissions**
- Speech Recognition (required)
- File Access (per-file basis)
- iCloud Access (optional)
- Minimal permission requests

---

### ⌨️ Keyboard Shortcuts

- **⌘N** - Add new files
- **⌘R** - Start transcription
- **⌘.** - Cancel transcription
- **⌘C** - Copy transcript
- **⌘,** - Open settings
- **Enter** - Send chat message
- **Shift+Enter** - New line in chat

---

### 📊 Metadata & Analytics

**Job Tracking**
- Creation, modification, completion dates
- Processing time
- File size and audio duration
- Word and character counts
- Confidence scores
- Language detection
- Format information

**Performance**
- Progress estimation
- Queue position tracking
- Detailed error logging
- Status history

---

### 🛠️ Developer Features

**Architecture**
- MVVM pattern with SwiftUI
- Actor-based services (thread-safe)
- Swift Concurrency (async/await)
- Combine for reactive data flow

**Services** (7 Actor-Based Services)
- AIService - Apple Intelligence
- TranscriptionService - Speech recognition
- AudioFileManager - Audio operations
- PersistenceService - File system
- DatabaseService - SQLite management
- ExportService - Multi-format export
- MemoryService - Context management

**Quality**
- Swift 6.0
- Type-safe throughout
- Memory-safe with ARC
- Actor isolation for thread safety
- Clean, maintainable codebase

---

### 🎯 Key Statistics

- **200+ total features**
- **70+ languages supported**
- **8+ audio formats**
- **5 export formats**
- **2 UI modes** (Standard/Advanced)
- **7 service actors**
- **3-tab interface**

## 🚀 Getting Started

### Requirements

- **macOS 26.0 (Tahoe) or later** - Required for Apple Intelligence features
- **Apple Silicon Mac** - Required for FoundationModels API
- **Xcode 26.0 or later** - For building from source
- **Speech Recognition permission** - Granted on first launch

### Installation

#### Option 1: Build from Source

1. Clone the repository:
```bash
git clone https://github.com/lanec/nitnab.git
cd nitnab
```

2. Open the project in Xcode:
```bash
open NitNab/NitNab.xcodeproj
```

3. Configure signing for your Apple account:
- Select the `NitNab` target in Xcode
- In **Signing & Capabilities**, choose your Team
- Set a unique Bundle Identifier (for example `com.yourname.nitnab`)

4. Build and run (⌘R)

#### Option 2: Download Release

Download the latest notarized release from the [Releases](https://github.com/lanec/nitnab/releases) page.

Each binary release includes:
- `NitNab-<version>-macOS-universal-notarized.zip`
- `NitNab-<version>-macOS-universal-notarized.zip.sha256`

After download:
```bash
shasum -a 256 -c NitNab-<version>-macOS-universal-notarized.zip.sha256
```

### First Launch

1. Launch NitNab
2. Grant Speech Recognition permission when prompted
3. Click "Browse Files" to select audio files (recommended over drag-and-drop)
4. Select your preferred language from the dropdown
5. Click "Start Transcription"
6. Click completed files to view transcripts
7. Use Summary tab to generate AI summaries
8. Use Chat tab to interact with the transcript

## 📖 Usage

### Adding Files

- **File Picker (Recommended)**: Click "Browse Files" to select files from Finder
  - Automatically grants file access permissions
  - Most reliable method
- **Drag & Drop**: Drag audio files directly onto the app window
  - May require Full Disk Access in System Settings
- **Batch Import**: Select multiple files at once for batch processing

### Transcribing

1. Add one or more audio files using "Browse Files"
2. Select the language from the dropdown (defaults to English)
3. Click "Start Transcription"
4. Monitor progress in real-time (time-based estimation)
5. Files process automatically, skipping empty audio files
6. Click any completed file to view results

### Viewing Results

**Transcript Tab**
- View full transcription text
- Click "Copy" button to copy entire transcript
- Text is selectable for partial copying

**Summary Tab**
- Click "Generate Summary" to create AI-powered summary
- Click "Copy" to copy summary text
- Click "Regenerate" for a new summary
- Powered by Apple Intelligence (FoundationModels)

**Chat Tab**
- Ask questions about the transcript
- Request email drafts or action items
- Get context-aware AI responses
- Conversation history maintained
- Try suggestions: "Draft an email about this", "What action items were mentioned?"

### Data Persistence & iCloud Sync

**Automatic Saving** (Enabled by Default)

When you transcribe files, NitNab automatically saves everything to a structured folder:

```
YourChosenFolder/NitNab/
├── nitnab.db                    # SQLite database tracking all transcriptions
└── 2025-10-09_15-30-45_MyRecording/
    ├── Audio/
    │   └── MyRecording.m4a      # Copy of original audio file
    ├── Transcript/
    │   ├── transcript.txt       # Full transcript text
    │   └── metadata.json        # Job details (duration, confidence, etc.)
    └── AI Summary/
        ├── summary.txt          # AI-generated summary (after generation)
        └── chat.json            # Chat conversation history
```

**Storage Options:**

1. **iCloud Drive (Recommended)**: Automatically syncs across all your Macs and future iOS devices
   - Uses app-specific ubiquitous container: `iCloud.$(CFBundleIdentifier)`
   - Location: `iCloud~<bundle-id>/Documents/NitNab/`
   - Select "Use iCloud Drive" in Settings → Persistence
   - Configured automatically on first launch if iCloud is available
   
2. **Custom Local Folder**: Store files anywhere on your Mac
   - Choose "Choose Folder..." in Settings → Persistence
   - Great for local-only storage or external drives

**Managing Persistence:**
- Toggle auto-save on/off in Settings → Persistence
- Files are saved after transcription, summary generation, and each chat message
- All data syncs via iCloud if that option is selected
- Future mobile app will access the same iCloud data

### Exporting

Export transcripts in multiple formats:

- **Plain Text (.txt)**: Simple, clean transcript
- **SRT (.srt)**: Subtitle format with timestamps
- **WebVTT (.vtt)**: Web video text tracks
- **JSON (.json)**: Structured data with metadata
- **Markdown (.md)**: Formatted document

Access export options from the Export menu in the header or file context menu.

### Keyboard Shortcuts

- `⌘N`: Add new files
- `⌘R`: Start transcription
- `⌘.`: Cancel transcription
- `⌘C`: Copy selected transcript
- `⌘,`: Open settings

## 🏗️ Architecture

NitNab is built with modern Swift and SwiftUI:

```
NitNab/
├── Models/              # Data models
│   ├── TranscriptionJob.swift       # Job state and metadata
│   ├── AudioFile.swift              # Audio file information
│   ├── TranscriptionResult.swift    # Transcript data
│   └── PersistedJobData.swift       # Serializable job data
├── Services/            # Business logic (Actor-based)
│   ├── AIService.swift              # Apple Intelligence integration
│   ├── AudioFileManager.swift       # Audio file operations
│   ├── TranscriptionService.swift   # Speech recognition
│   ├── ExportService.swift          # Multi-format export
│   ├── PersistenceService.swift     # File system persistence
│   └── DatabaseService.swift        # SQLite job tracking
├── ViewModels/          # MVVM view models
│   └── TranscriptionViewModel.swift # Main app coordinator
└── Views/               # SwiftUI views
    ├── ContentView.swift            # Main app container
    ├── HeaderView.swift             # Top bar with controls
    ├── DropZoneView.swift           # File drop target
    ├── FileListView.swift           # Job list sidebar
    ├── TranscriptView.swift         # Three-tab interface
    └── SettingsView.swift           # App configuration
```

### Key Technologies

- **SwiftUI**: Modern declarative UI framework
- **Swift Concurrency**: Async/await and actors for clean asynchronous code
- **Actors**: Thread-safe service layer with isolated state
- **SFSpeechRecognizer**: Apple's on-device speech-to-text API
- **FoundationModels**: Apple Intelligence for summaries and chat (macOS 26+)
- **LanguageModelSession**: On-device LLM integration
- **AVFoundation**: Audio file processing and format conversion
- **SQLite**: Database for job tracking and metadata
- **FileManager**: iCloud and local file system integration
- **MVVM Architecture**: Clean separation of concerns

### Design Principles

- **Privacy-First**: All processing happens on-device, no cloud services
- **Offline-Capable**: Works without internet connection
- **Actor-Based Concurrency**: Thread-safe by design
- **Persistent State**: Jobs and transcripts survive app restarts
- **iCloud Sync Ready**: Built for seamless cross-device sync

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with Apple's SpeechTranscriber API
- Inspired by the need for privacy-focused, local transcription tools
- Thanks to the Swift and macOS developer community

## 📧 Contact

Lane Campbell - [@lanec](https://github.com/lanec)

Project Link: [https://github.com/lanec/nitnab](https://github.com/lanec/nitnab)

Website: [https://www.nitnab.com](https://www.nitnab.com)

## 🔧 Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/lanec/nitnab.git
cd nitnab

# Open in Xcode
open NitNab/NitNab.xcodeproj

# Build and run
# Press ⌘R or Product > Run
```

### Project Structure

The project follows clean MVVM architecture with actor-based services:

- **Models**: Immutable data structures
- **Services**: Actor-isolated business logic
- **ViewModels**: @MainActor view coordinators
- **Views**: SwiftUI declarative UI

### Testing

Run tests with:
```bash
xcodebuild test -project NitNab/NitNab.xcodeproj -scheme NitNab
```

### Release Process (Notarized Binary)

NitNab keeps release identities out of tracked files (`com.example.*` stays in repo) and injects real signing values only at release time.

Required environment variables:
- `RELEASE_BUNDLE_ID`
- `APPLE_TEAM_ID`
- `DEVELOPER_ID_APPLICATION`
- `APPLE_DEVELOPER_ID_P12_BASE64`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`
- `APPLE_KEY_ID`
- `APPLE_ISSUER_ID`
- `APPLE_API_PRIVATE_KEY_P8_BASE64`

Manual fallback release command:
```bash
./scripts/release/notarize_and_release.sh 1.0.4
```

Validation command for downloaded artifacts:
```bash
./scripts/release/validate_notarized_artifact.sh ./NitNab-1.0.4-macOS-universal-notarized.zip
```

## 🐛 Troubleshooting

### Speech Recognition Not Working

- **Check Permissions**: Go to System Settings → Privacy & Security → Speech Recognition
- **Enable for NitNab**: Make sure NitNab is checked
- **Restart the App**: Quit and relaunch NitNab

### Files Not Persisting

- **Database Migration**: The app automatically migrates old database schemas
- **Check Storage**: Ensure sufficient disk space in your iCloud or local storage
- **View Logs**: Check Console.app for any error messages from NitNab

### Apple Intelligence Features Not Available

- **Requirements**: macOS 26.0+ and Apple Silicon required
- **Enable Apple Intelligence**: System Settings → Apple Intelligence
- **Language**: Currently Apple Intelligence requires English (US)

### Build Errors

- **Xcode Version**: Ensure you're using Xcode 26.0 or later
- **macOS SDK**: The project requires macOS 26.0 SDK
- **Clean Build**: Try Product → Clean Build Folder (⌘⇧K)

## 🗺️ Roadmap

### Completed ✅
- [x] Multi-language transcription
- [x] AI-powered summarization
- [x] Interactive AI chat
- [x] Batch processing
- [x] iCloud sync for transcripts
- [x] Database persistence
- [x] Multiple export formats

### Planned 🎯
- [ ] Live audio recording and transcription
- [ ] Speaker diarization (multiple speakers)
- [ ] Streaming transcription with real-time updates
- [ ] Custom vocabulary support
- [ ] iOS/iPadOS companion app
- [ ] Shortcuts integration
- [ ] Share extension for system-wide transcription
- [ ] Timeline view with segment navigation

## 📸 Screenshots

> Screenshots coming soon

---

Made with ❤️ by Lane Campbell
