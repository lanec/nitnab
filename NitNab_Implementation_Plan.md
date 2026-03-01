# NitNab — Liquid Glass Implementation Plan

**Prepared by:** Deloitte Digital
**Client:** Apple — Lead Designer Direction
**Date:** February 26, 2026
**Version:** 1.0
**Classification:** Confidential

---

## Executive Summary

This document outlines the full implementation plan for applying the Liquid Glass brand direction (Direction 05) to the NitNab macOS application. NitNab is a privacy-first, on-device transcription app targeting macOS Tahoe 26+, built with Swift 6 and SwiftUI, powered by Apple Intelligence via the FoundationModels API and SFSpeechRecognizer.

The Liquid Glass direction uses macOS Tahoe's translucent material system with a contextual tint approach — each functional area of the app receives its own system color identity while remaining 100% within Apple's HIG specifications.

---

## 1. Brand Direction Summary

**Direction:** Liquid Glass (Direction 05)
**Material:** `.glassEffect()` translucent surfaces with backdrop blur
**Tint System:** Contextual — color shifts by app context
**Typography:** SF Pro via `.system()` exclusively
**Colors:** Apple system palette only — zero custom hex values
**Grid:** Apple 8pt spacing grid
**Corners:** Continuous superellipse (`.continuous`)

### Contextual Tint Mapping

| Context | Color | SwiftUI | Application Area |
|---------|-------|---------|-----------------|
| Transcript | .blue | `.tint(.blue)` | Transcript tab, text view, word count |
| Summary | .indigo | `.tint(.indigo)` | AI summary, key points, action items |
| Chat | .purple | `.tint(.purple)` | Chat interface, AI responses, prompts |
| Privacy | .green | `.tint(.green)` | On-device badge, privacy checkmarks |
| Audio | .orange | `.tint(.orange)` | Waveform, playback, recording status |

### Glass Material Tokens

| Property | Light | Dark |
|----------|-------|------|
| Background | `rgba(255,255,255,0.72)` | `rgba(28,28,30,0.65)` |
| Border | `rgba(255,255,255,0.40)` | `rgba(255,255,255,0.06)` |
| Backdrop blur | 40pt | 40pt |
| Secondary glass | `rgba(255,255,255,0.50)` | `rgba(28,28,30,0.45)` |
| Secondary blur | 20pt | 20pt |

---

## 2. Current State Assessment

### Application Architecture

- **Version:** 1.0.2 (Build 3)
- **Language:** Swift 6, SwiftUI
- **Target:** macOS 26.0+ (Apple Silicon)
- **Pattern:** MVVM with actor-based concurrency
- **LOC:** ~6,851 across 12 views, 8 services, 5 models, 1 view model

### Source File Inventory

**Views (12 files):**
AdvancedView.swift, CompanyPickerSheet.swift, ContentView.swift, DropZoneView.swift, FileListView.swift, HeaderView.swift, MemoriesSettingsView.swift, SearchBarView.swift, SettingsView.swift, StandardView.swift, TagCloudView.swift, TranscriptView.swift

**Services (8 files):**
AIService.swift, AudioFileManager.swift, DatabaseService.swift, DuplicateDetectionService.swift, ExportService.swift, MemoryService.swift, PersistenceService.swift, TranscriptionService.swift

**View Models (1 file):**
TranscriptionViewModel.swift

**Models (5 files):**
AudioFile.swift, Memory.swift, PersistedJobData.swift, TranscriptionJob.swift, TranscriptionResult.swift

### Current Design State

The app currently uses `Color(nsColor: .controlBackgroundColor)` and `.systemBlue` for basic system coloring. No `.glassEffect()` modifiers are applied. No contextual tinting is implemented. Corner radius uses standard `.cornerRadius()` rather than `.clipShape(.rect(cornerRadius:, style: .continuous))`.

---

## 3. Implementation Phases

### Phase 1: Foundation (Week 1-2)

**1.1 Create Design Token Layer**
- Create `NitNabTokens.swift` with spacing, radius, and tint enums
- Define `NitNabContext` enum mapping tabs to system colors
- Create `GlassModifier` ViewModifier wrapping `.glassEffect()`
- Establish `NitNabTint` environment key for contextual tinting

**1.2 App Shell Updates**
- Update `NitNabApp.swift` to inject contextual tint environment
- Apply `.glassEffect()` to WindowGroup container
- Replace `.windowStyle(.hiddenTitleBar)` with Tahoe-native window chrome
- Configure sidebar width to 240pt default

**1.3 Typography Audit**
- Audit all 12 view files for hardcoded font sizes
- Replace all `.font(.system(size:))` with Dynamic Type tokens
- Ensure `.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.body`, `.callout`, `.subheadline`, `.footnote`, `.caption`, `.caption2` are used correctly
- Verify all text supports Dynamic Type accessibility scaling

### Phase 2: Core Views (Week 3-4)

**2.1 ContentView Refactor**
- Apply glass material to main container
- Implement tab-aware tint switching
- Replace `Color(nsColor: .controlBackgroundColor)` with system semantic colors
- Add `.clipShape(.rect(cornerRadius: 16, style: .continuous))` to panels

**2.2 StandardView + AdvancedView**
- Apply `.tint(.blue)` on transcript sections
- Apply `.tint(.indigo)` on summary sections
- Apply `.tint(.purple)` on chat sections
- Apply `.tint(.green)` on privacy indicators
- Apply `.tint(.orange)` on audio/waveform elements
- Add glass material to card containers

**2.3 DropZoneView**
- Redesign drop zone with glass material
- Animate tint on file hover (`.orange` for audio context)
- Apply 16pt continuous corner radius
- Add glass inner surface for accepted files

**2.4 TranscriptView**
- Apply blue tint context
- Glass material on transcript container
- Continuous corners on text blocks
- 8pt grid spacing audit

**2.5 FileListView + SearchBarView**
- Glass material on list rows
- 12pt continuous corners on row items
- Search bar with glass background
- 8pt grid spacing

### Phase 3: Supporting Views (Week 5-6)

**3.1 HeaderView**
- Glass toolbar background
- Contextual tint for active tab indicator
- 52pt toolbar height per HIG
- Pill-shaped controls (980pt / Capsule)

**3.2 SettingsView + MemoriesSettingsView**
- Standard grouped list styling
- System colors for all controls
- Proper 20pt card internal padding
- 8pt chip spacing

**3.3 TagCloudView + CompanyPickerSheet**
- Pill-shaped tags with 8pt corners
- Glass sheet presentation for picker
- 22pt continuous corners on modals

### Phase 4: Polish & QA (Week 7-8)

**4.1 Light/Dark Appearance Audit**
- Verify all glass materials in both appearances
- Test contextual tints in light and dark
- Validate contrast ratios for accessibility (WCAG AA)
- Screenshot comparison against brand kit

**4.2 Dynamic Type Testing**
- Test all 11 text styles at all Dynamic Type sizes
- Verify layout doesn't break at largest sizes
- Ensure truncation and line wrapping are handled

**4.3 Animation & Transitions**
- Smooth tint transitions between tabs
- Glass material fade-in on view appearance
- Drop zone animation polish
- Respect Reduce Motion accessibility setting

**4.4 Performance Testing**
- Measure `.glassEffect()` GPU impact
- Profile backdrop blur rendering at 40pt
- Test on minimum supported hardware
- Verify no frame drops during transcription

---

## 4. Spacing & Layout Remediation

All views must be audited against the Apple 8pt grid:

| Token | Value | NitNab Usage |
|-------|-------|-------------|
| space.2xs | 4pt | Icon-to-label inline gap |
| space.xs | 8pt | Chip internal, tight groupings |
| space.sm | 12pt | Related element pairs |
| space.md | 16pt | Standard content padding |
| space.lg | 20pt | Card internal, form fields |
| space.xl | 24pt | Section separation |
| space.2xl | 32pt | Group separation |
| space.3xl | 40pt | Major layout divisions |
| space.4xl | 64pt | Hero/header regions |

Current code uses ad-hoc padding values. All must be replaced with token-based spacing.

---

## 5. Corner Radius Standardization

| Token | Value | Usage |
|-------|-------|-------|
| radius.sm | 8pt | Buttons, chips, small controls |
| radius.md | 12pt | Cards, list rows |
| radius.lg | 16pt | Panels, grouped containers |
| radius.xl | 22pt | Modals, sheets |
| radius.pill | 980pt | Pills, full-round buttons |

All instances of `.cornerRadius()` must be replaced with `.clipShape(.rect(cornerRadius:, style: .continuous))`.

---

## 6. Testing Strategy

### Unit Tests
- Token value assertions (spacing grid, radius values)
- Context-to-tint mapping verification
- Glass modifier output validation

### UI Tests
- Screenshot-based regression testing per view
- Light/dark appearance matrix
- Dynamic Type scaling at all sizes
- VoiceOver accessibility traversal

### Manual QA Checklist
- Every screen compared to brand kit PDF
- Tint transitions verified across all 5 contexts
- Glass material rendering on M1, M2, M3, M4 hardware
- Performance profiling on minimum-spec machine

---

## 7. Deliverables

| Deliverable | Format | Status |
|-------------|--------|--------|
| Liquid Glass Brand Kit | .html, .pdf | Complete |
| Implementation Plan | .md, .docx | Complete |
| Project Timeline | .xlsx | Complete |
| Design Token Reference | In brand kit | Complete |
| SwiftUI Implementation Guide | In brand kit | Complete |

---

## 8. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `.glassEffect()` performance on older Apple Silicon | Medium | High | Profile early; provide opaque fallback |
| Liquid Glass API changes in Tahoe beta | Low | High | Pin to stable API surface; monitor WWDC |
| Dynamic Type breaks glass layouts | Medium | Medium | Test all 7 size categories in Phase 4 |
| Contrast ratio failures on glass | Medium | High | Pre-validate all tint/glass combinations |
| Scope creep from Apple Design review | High | Medium | Phase-gate deliverables; weekly sign-off |

---

## 9. Team & Governance

**Deloitte Digital Team:**
- Engagement Lead — Client relationship, Apple Design liaison
- Design Lead — Brand kit fidelity, HIG compliance review
- SwiftUI Engineers (2) — Implementation, token system, glass materials
- QA Lead — Accessibility, performance, visual regression
- Project Manager — Timeline, risk management, sprint planning

**Apple Counterparts:**
- Lead Designer — Creative direction, approval authority
- SwiftUI Framework Engineer — `.glassEffect()` technical guidance
- HIG Review — Compliance sign-off

**Cadence:**
- Weekly design review with Apple Lead Designer
- Bi-weekly sprint demos
- Phase-gate approval at end of each phase

---

*Prepared under Apple Design direction. Confidential.*
