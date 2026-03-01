# NitNab Quick Start Guide

> For detailed documentation, see the [main README](README.md)

Get up and running with NitNab in 5 minutes! 🚀

## Installation
- macOS 26.0 or later
- Xcode 26.0 or later (for building from source)

### Build & Run

```bash
# Clone the repository
git clone https://github.com/lanec/nitnab.git
cd nitnab

# Open in Xcode
open NitNab/NitNab.xcodeproj

# Press ⌘R to build and run
```

## First Use

### 1. Grant Permissions
When NitNab launches for the first time, click **OK** to grant Speech Recognition permission.

### 2. Add Audio Files
- **Drag & Drop**: Drag audio files onto the window
- **Browse**: Click "Browse Files" button

### 3. Select Language
Choose your audio's language from the dropdown menu (defaults to English).

### 4. Start Transcription
Click **"Start Transcription"** and watch the magic happen! ✨

### 5. Export Results
Once complete, click the **Export** button and choose your format:
- Plain Text (.txt)
- SRT Subtitles (.srt)
- WebVTT (.vtt)
- JSON (.json)
- Markdown (.md)

## Supported Audio Formats

✅ M4A, WAV, MP3, AIFF, CAF, FLAC, AAC

## Tips

- **Batch Processing**: Add multiple files and they'll transcribe sequentially
- **Copy to Clipboard**: Right-click any completed job to copy the transcript
- **Retry Failed Jobs**: Click the menu on failed jobs to retry
- **View Segments**: Switch to "Segments" tab to see timestamped chunks

## Keyboard Shortcuts

- `⌘N` - Add files
- `⌘R` - Start transcription
- `⌘.` - Cancel transcription
- `⌘C` - Copy transcript
- `⌘,` - Settings

## Need Help?

- 📖 Full documentation: [README.md](README.md)
- 🔧 Setup guide: [SETUP.md](SETUP.md)
- 🐛 Report issues: [GitHub Issues](https://github.com/lanec/nitnab/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/lanec/nitnab/discussions)

---

Made with ❤️ by Lane | [nitnab.com](https://www.nitnab.com)
