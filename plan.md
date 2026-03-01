# NitNab Liquid Glass — Implementation Plan

**Role:** Deloitte Digital delivery team, Google tech lead oversight
**Scope:** Align running app to Brand_Guidelines.md + Implementation_Plan.md
**Constraint:** macOS Tahoe 26 (Swift 6, SwiftUI), no new files unless essential

---

## Problem Statement

The app currently looks like a stock macOS prototype. From the screenshots:
- Header shows a **generic gray placeholder icon**, not the brand microphone
- Everything is flat/opaque `Color(nsColor: .controlBackgroundColor)` — zero glass
- No blue-to-indigo gradient identity anywhere
- No contextual tinting (Transcript=blue, Summary=indigo, Chat=purple)
- Corner radii are inconsistent and use circular arcs, not continuous superellipse
- Spacing is ad-hoc, not on the 8pt grid
- DesignSystem.swift tokens don't match the implementation plan values
- TranscriptionService is missing locale reservation cleanup (Yap pattern)

---

## Step 0: Align TranscriptionService with Yap's Speech.framework pattern

NitNab already uses the same `SpeechTranscriber` + `SpeechAnalyzer` API as
[Yap](https://github.com/finnvoor/yap). However, Yap includes a critical
locale reservation cleanup step that NitNab is missing.

**File:** `NitNab/Services/TranscriptionService.swift`

**Fix `prepareLocale()`** — release previously reserved locales before reserving
a new one (prevents asset leaks across multiple transcriptions):
```swift
private func prepareLocale(_ locale: Locale) async throws {
    let supportedLocales = await SpeechTranscriber.supportedLocales
    guard supportedLocales.contains(where: {
        $0.identifier(.bcp47) == locale.identifier(.bcp47)
    }) else {
        throw TranscriptionError.unsupportedLocale(locale)
    }

    // Release previously reserved locales (Yap pattern)
    for reserved in await AssetInventory.reservedLocales {
        await AssetInventory.release(reservedLocale: reserved)
    }
    try await AssetInventory.reserve(locale: locale)

    // Download assets if not installed
    let installedLocales = await SpeechTranscriber.installedLocales
    if !installedLocales.contains(where: {
        $0.identifier(.bcp47) == locale.identifier(.bcp47)
    }) {
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )
        if let request = try await AssetInventory.assetInstallationRequest(
            supporting: [transcriber]
        ) {
            try await request.downloadAndInstall()
        }
    }
}
```

Key alignment points with Yap:
- Release all `AssetInventory.reservedLocales` before reserving new ones
- Reserve locale BEFORE checking installed status (Yap's ordering)
- Separate the "is supported?" check from the "is installed?" check
- The transcriber for asset download is temporary (matches Yap)

---

## Step 1: Fix DesignSystem.swift tokens to match the Implementation Plan

The current `Brand.Radius` and `Brand.Spacing` values don't match the implementation
plan's specification. Update them:

**Radius** (current → target):
- `small: 6` → `8`  (buttons, chips, small controls)
- `medium: 10` → `12` (cards, list rows)
- `large: 14` → `16` (panels, grouped containers)
- `extraLarge: 20` → `22` (modals, sheets)
- ADD `pill: CGFloat = 980` (pills, full-round buttons)

**Spacing** — align to strict 8pt grid (current → target):
- `xxs: 2` → `4` (rename to align with plan's `space.2xs`)
- `xs: 4` → `8`
- `sm: 8` → `12`
- `md: 12` → `16`
- `lg: 16` → `20`
- `xl: 20` → `24`
- `xxl: 24` → `32`
- ADD `xxxl: CGFloat = 40`
- ADD `xxxxl: CGFloat = 64`

**Add glass modifier** — a reusable ViewModifier wrapping `.glassEffect()`:
```swift
func brandGlass(radius: CGFloat = Brand.Radius.lg) -> some View {
    self.glassEffect(.regular.tint(Brand.primary),
                     in: .rect(cornerRadius: radius, style: .continuous))
}
```

**Add continuous-corner helper**:
```swift
func continuousRadius(_ r: CGFloat) -> some View {
    self.clipShape(.rect(cornerRadius: r, style: .continuous))
}
```

**Replace `brandCard()`** — swap opaque background for glass:
```swift
func brandCard() -> some View {
    self.glassEffect(.regular, in: .rect(cornerRadius: Brand.Radius.md, style: .continuous))
}
```

**Replace `brandTag()`** — use continuous corners.

**Replace `brandStatusBackground()`** — use continuous corners.

---

## Step 2: HeaderView — Brand identity (the biggest visual win)

This is what the user sees first. Currently a gray toolbar with a broken icon.

- **App icon**: The image `"AppIcon"` lookup fails → falls back to generic SF Symbol.
  Fix: Use `NSApp.applicationIconImage` or load from the asset catalog correctly.
  Apply `.clipShape(.rect(cornerRadius: 10, style: .continuous))` per brand guide.
- **Background**: Replace `Color(nsColor: .windowBackgroundColor)` with
  `.glassEffect(.regular, in: .rect(cornerRadius: 0))` for glass toolbar.
- **"Start Transcription" button**: Apply brand gradient as button background
  (blue→indigo, 135°) to reinforce brand identity. This is the hero CTA.
- **Tint the header** based on active context (blue default).

---

## Step 3: ContentView + StandardView — Glass shell & contextual tint

- **StandardView**: Apply `.tint(.blue)` as default context tint.
- **ContentView error/empty states**:
  - Replace `Color(nsColor: .controlBackgroundColor)` with glass material.
  - Replace `.cornerRadius(Brand.Radius.medium)` with `.continuousRadius(Brand.Radius.md)`.
- **EmptyTranscriptView**: Replace generic icon with brand-colored microphone icon,
  apply brand gradient to the icon.

---

## Step 4: TranscriptView — Contextual tinting per tab

This is a multi-tab view (Transcript, Summary, Chat) and the implementation plan
says each should get its own tint:

- **Transcript tab**: `.tint(.blue)` — already uses `Brand.primary` in places
- **Summary tab**: `.tint(.indigo)` — swap icon/accent colors to indigo
- **Chat tab**: `.tint(.purple)` — swap message bubble and icon to purple
- Replace all `Color(nsColor: .controlBackgroundColor)` with glass.
- Replace all `.cornerRadius()` with `.continuousRadius()`.
- Chat input bar: glass background.
- Message bubbles: continuous corners.

---

## Step 5: FileListView — Glass rows & continuous corners

- Replace list/row backgrounds (`Color(nsColor: .controlBackgroundColor)`,
  `.textBackgroundColor`) with glass material or `.clear` (let glass show through).
- Replace `.cornerRadius(Brand.Radius.medium)` with `.continuousRadius()`.
- Selected row indicator: use `Brand.primary` with continuous corner clip.

---

## Step 6: DropZoneView — Refine

Already partially branded (uses `Brand.primary`, `Brand.primaryLight`,
`Brand.Radius.extraLarge`). Remaining fixes:
- Replace `.font(.system(size: 80))` with `.font(.system(size: Brand.IconSize.hero))`.
- Replace `Color.secondary.opacity(0.3)` border with a semantic token.
- Apply glass material inside the dashed border when files are being dragged over.
- Continuous corners on the dashed rectangle.

---

## Step 7: AdvancedView, SearchBarView, TagCloudView — Supporting views

- **AdvancedView**: Replace all `Color(nsColor: .controlBackgroundColor)` with glass.
  Fix `.font(.system(size: 64))` → `Brand.IconSize.feature`. Continuous corners.
- **SearchBarView**: Replace `Color(nsColor: .textBackgroundColor)` with glass input.
  Continuous corners.
- **TagCloudView**: Replace `.cornerRadius()` with `.continuousRadius()`.

---

## Step 8: SettingsView, MemoriesSettingsView, CompanyPickerSheet — Sheets/modals

- Replace all `Color(nsColor: .controlBackgroundColor)` backgrounds with glass.
- Replace all `.cornerRadius()` with `.continuousRadius()`.
- Modal sheets: apply `.continuousRadius(Brand.Radius.xl)` (22pt).
- Keep `.formStyle(.grouped)` — this is standard macOS.

---

## Step 9: NitNabApp.swift — Window-level polish

- Remove `.windowStyle(.hiddenTitleBar)` — let macOS Tahoe show native glass
  title bar chrome (this is what the Liquid Glass direction calls for).
- Consider adding `.windowStyle(.automatic)` for native Tahoe glass window frame.

---

## Execution Order (by impact)

| Priority | Step | Files Changed | Visual Impact |
|----------|------|---------------|---------------|
| P0 | Step 0 | TranscriptionService.swift | Transcription reliability (Yap alignment) |
| P0 | Step 1 | DesignSystem.swift | Foundation for everything |
| P0 | Step 2 | HeaderView.swift | Hero identity — user sees this first |
| P0 | Step 3 | ContentView.swift, StandardView.swift | Glass shell |
| P1 | Step 4 | TranscriptView.swift | Contextual tint differentiation |
| P1 | Step 5 | FileListView.swift | Sidebar polish |
| P2 | Step 6 | DropZoneView.swift | Drop zone refinement |
| P2 | Step 7 | AdvancedView, SearchBarView, TagCloudView | Supporting views |
| P2 | Step 8 | SettingsView, MemoriesSettingsView, CompanyPickerSheet | Modals |
| P3 | Step 9 | NitNabApp.swift | Window chrome |
