# NitNab — Brand Icon Guidelines

**Direction 05: Liquid Glass**
Prepared by Deloitte Digital under Apple Design Leadership · February 2026

---

## App Icon Design

The NitNab app icon is a white microphone silhouette on a blue-to-indigo gradient background, rendered as a continuous superellipse (squircle) matching macOS Tahoe's icon shape language.

### Design Specification

| Property | Value |
|---|---|
| **Mark** | White microphone silhouette (centered) |
| **Background** | `linear-gradient(135deg, #007AFF, #5856D6)` |
| **Shape** | Continuous superellipse (macOS squircle) |
| **Corner radius** | ~22% of icon size (superellipse, not circular arcs) |
| **Shadow** | `0 6px 24px rgba(0,122,255,0.25)` — applied by macOS, not baked in |
| **Mark sizing** | ~48% of icon height |

### Color Tokens

| Element | Light | Dark | SwiftUI |
|---|---|---|---|
| Gradient start | `#007AFF` | `#0A84FF` | `.blue` |
| Gradient end | `#5856D6` | `#5E5CE6` | `.indigo` |
| Mark | `#FFFFFF` | `#FFFFFF` | `.white` |

### Why a Microphone

NitNab is fundamentally an audio transcription app. The microphone is the universal symbol for audio capture and directly communicates the app's core function. It aligns with Apple's system microphone indicator and the SF Symbol `mic.fill` used throughout macOS.

---

## Exported Assets

### macOS Dock Icons (Superellipse corners, transparent background)

| File | Size | Usage |
|---|---|---|
| `AppIcon_1024.png` | 1024x1024 | App Store submission, marketing |
| `AppIcon_512.png` | 512x512 | App Store, Finder preview |
| `AppIcon_256.png` | 256x256 | Finder, About window |
| `AppIcon_128.png` | 128x128 | Dock (standard density) |
| `AppIcon_64.png` | 64x64 | Spotlight, grid view |
| `AppIcon_32.png` | 32x32 | Dock (small), list view |
| `AppIcon_16.png` | 16x16 | Menu bar, sidebar |

### iOS / Mobile Icons (Square — OS applies corner mask)

| File | Size | Usage |
|---|---|---|
| `AppIcon_iOS_180.png` | 180x180 | iPhone @3x |
| `AppIcon_iOS_167.png` | 167x167 | iPad Pro @2x |
| `AppIcon_iOS_152.png` | 152x152 | iPad @2x |
| `AppIcon_iOS_120.png` | 120x120 | iPhone @2x |
| `AppIcon_iOS_76.png` | 76x76 | iPad @1x |

### In-App Vector Icons (SVG)

| File | Variant | Usage |
|---|---|---|
| `AppIcon_InApp_Light.svg` | Light mode | About screen, onboarding, in-app branding |
| `AppIcon_InApp_Dark.svg` | Dark mode | Same contexts with dark tint adjustment |

---

## Usage Rules

### Do

- Use the superellipse-cornered versions for macOS contexts
- Use the square versions for iOS (the OS masks the corners)
- Allow the OS to apply the drop shadow — do not bake shadows into the icon
- Display on dark backgrounds for maximum impact
- Use SVG versions for variable-size contexts

### Don't

- Do not add extra effects, glows, or borders around the icon
- Do not stretch or distort the squircle shape
- Do not replace the microphone with any other symbol
- Do not use the icon at sizes smaller than 16x16
- Do not use circular masks — always use the continuous superellipse
- Do not modify the gradient colors
- Do not place the icon on a blue or indigo background (low contrast)

### Clear Space

Maintain clear space equal to 15% of the icon size on all sides.

### Contextual Tint (In-App Only)

When the icon appears inline within the app, it may inherit the contextual tint of the active tab:

| Context | Tint | SwiftUI |
|---|---|---|
| Transcript | `.blue` | `.tint(.blue)` |
| Summary | `.indigo` | `.tint(.indigo)` |
| Chat | `.purple` | `.tint(.purple)` |

---

## Implementation

```swift
// Xcode Asset Catalog
// Place AppIcon_1024.png in Assets.xcassets -> AppIcon
// macOS: 1024, 512, 256, 128, 64, 32, 16
// iOS: 180, 167, 152, 120, 76

// In-app icon reference (SwiftUI)
Image("AppIcon")
    .resizable()
    .frame(width: 64, height: 64)
    .clipShape(.rect(cornerRadius: 14, style: .continuous))
```

---

**NitNab** — Nifty Instant Transcription, Nifty AutoSummarize Buddy
macOS Tahoe 26 · Apple Intelligence · 100% On-Device
