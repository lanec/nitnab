# NitNab Setup Guide

This guide will help you set up and build NitNab from source.

## Prerequisites

Before you begin, ensure you have:

- **macOS 26.0 or later** installed on your Mac
- **Xcode 26.0 or later** installed from the Mac App Store
- **Command Line Tools** installed (run `xcode-select --install` if needed)

## Building from Source

### 1. Clone the Repository

```bash
git clone https://github.com/lanec/nitnab.git
cd nitnab
```

### 2. Open in Xcode

```bash
open NitNab/NitNab.xcodeproj
```

Alternatively, you can:
- Double-click `NitNab.xcodeproj` in Finder
- Open Xcode and use File → Open, then select the project

### 3. Configure Signing

1. Select the **NitNab** project in the Project Navigator
2. Select the **NitNab** target
3. Go to the **Signing & Capabilities** tab
4. Choose your **Team** from the dropdown
5. Xcode will automatically manage your signing certificate

### 4. Build and Run

**Option A: Using Xcode**
- Press `⌘R` or click the Play button in the toolbar
- Xcode will build and launch NitNab

**Option B: Using Command Line**
```bash
xcodebuild -scheme NitNab -configuration Release build
```

The built app will be in:
```
DerivedData/NitNab/Build/Products/Release/NitNab.app
```

## First Launch Setup

### 1. Grant Permissions

When you first launch NitNab, macOS will request permissions:

1. **Speech Recognition**: Click "OK" to allow
   - Required for transcription functionality
   - Can be managed in System Settings → Privacy & Security → Speech Recognition

2. **File Access**: Automatically granted when you select files
   - NitNab uses sandboxed file access
   - Only files you explicitly select are accessible

### 2. Verify Installation

1. Launch NitNab
2. You should see the welcome screen with a drop zone
3. Try adding a sample audio file to test

## Development Setup

### Project Structure

```
NitNab/
├── NitNab/
│   ├── NitNabApp.swift          # App entry point
│   ├── Models/                   # Data models
│   ├── Services/                 # Business logic
│   ├── ViewModels/               # MVVM view models
│   ├── Views/                    # SwiftUI views
│   ├── Assets.xcassets/          # Images and colors
│   ├── Info.plist                # App configuration
│   └── NitNab.entitlements       # App capabilities
├── NitNab.xcodeproj/             # Xcode project
├── README.md                     # Documentation
├── LICENSE                       # MIT License
└── CONTRIBUTING.md               # Contribution guidelines
```

### Running Tests

```bash
# Run all tests
xcodebuild -scheme NitNab test

# Or in Xcode: ⌘U
```

### Code Style

The project follows:
- Swift API Design Guidelines
- SwiftUI best practices
- MVVM architecture pattern

### Debugging

**Enable Debug Logging:**
1. Edit the scheme (Product → Scheme → Edit Scheme)
2. Select "Run" → "Arguments"
3. Add environment variable: `DEBUG_LOGGING = 1`

**Common Issues:**

- **"SpeechTranscriber not found"**: Ensure you're running macOS 26.0+
- **Build fails**: Clean build folder (⌘⇧K) and rebuild
- **Signing errors**: Check your Apple Developer account in Xcode preferences

## Distribution

### Creating a Release Build (Notarized)

NitNab keeps tracked project signing identifiers sanitized (`com.example.*`).  
For distributable binaries, inject release identities at build time only.

Required environment variables:

- `RELEASE_BUNDLE_ID` (for example `com.lanec.nitnab`)
- `APPLE_TEAM_ID` (for example `YSG28M8Y96`)
- `DEVELOPER_ID_APPLICATION` (full certificate name)
- `APPLE_DEVELOPER_ID_P12_BASE64`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`
- `APPLE_KEY_ID`
- `APPLE_ISSUER_ID`
- `APPLE_API_PRIVATE_KEY_P8_BASE64`

Manual release command:

```bash
./scripts/release/notarize_and_release.sh 1.0.4
```

### Build-Only (No Notarization)

If you only need a local build artifact:

```bash
xcodebuild -scheme NitNab \
  -configuration Release \
  -archivePath ./build/NitNab.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath ./build/NitNab.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

### Validate Downloaded Notarized Artifact

```bash
./scripts/release/validate_notarized_artifact.sh ./NitNab-1.0.4-macOS-universal-notarized.zip
```

## Troubleshooting

### macOS Version Check

Verify you're running macOS 26.0+:
```bash
sw_vers
```

### Xcode Version Check

Verify Xcode version:
```bash
xcodebuild -version
```

### Clean Build

If you encounter build issues:
```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/NitNab-*

# Or in Xcode: Product → Clean Build Folder (⌘⇧K)
```

### Reset Permissions

If speech recognition isn't working:
```bash
tccutil reset SpeechRecognition com.example.nitnab
```

Then relaunch NitNab and grant permissions again.

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/lanec/nitnab/issues)
- **Discussions**: [GitHub Discussions](https://github.com/lanec/nitnab/discussions)
- **Email**: Contact [@lanec](https://github.com/lanec)

## Next Steps

- Read the [README](README.md) for usage instructions
- Check out [CONTRIBUTING](CONTRIBUTING.md) to contribute
- Visit [nitnab.com](https://www.nitnab.com) for more information

---

Happy transcribing! 🎙️
