# NitNab: Design Review & Feature Implementation Plan

**Prepared by:** Design & Engineering Review Team
**Client:** NitNab — macOS Speech Transcription Application
**Date:** February 26, 2026
**Version:** 1.0

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Audit: Current State Assessment](#2-product-audit-current-state-assessment)
3. [Competitive Landscape Analysis](#3-competitive-landscape-analysis)
4. [Platform Alignment: macOS 26 Tahoe & Liquid Glass](#4-platform-alignment-macos-26-tahoe--liquid-glass)
5. [Feature Plan: Three Pillars of Improvement](#5-feature-plan-three-pillars-of-improvement)
6. [UX Polish & Usability Recommendations](#6-ux-polish--usability-recommendations)
7. [Accessibility & Inclusivity](#7-accessibility--inclusivity)
8. [Implementation Roadmap](#8-implementation-roadmap)
9. [Appendix: Detailed Issue Registry](#9-appendix-detailed-issue-registry)

---

## 1. Executive Summary

NitNab is a macOS 26+ speech transcription application built on Apple's native SpeechTranscriber API and Apple Intelligence. It offers dual-mode UI (Standard and Advanced), company/vocabulary context for improved accuracy, iCloud-first persistence, and AI-powered post-processing.

This review identifies **26 UX issues** across the product, benchmarks NitNab against four leading competitors (Otter.ai, MacWhisper, Descript, Rev.com), and delivers a revised implementation plan for three user-requested features:

1. **Per-File Transcription** — Transcribe individual files on-add instead of batch-only
2. **Bulk Summarization** — Batch-summarize completed transcriptions with Apple Intelligence
3. **Smart File Renaming** — Auto-generate file names from recording date, content description, and speaker names

Each feature plan has been revised based on competitive analysis, Apple Human Interface Guidelines, Liquid Glass design patterns, and a thorough codebase audit.

---

## 2. Product Audit: Current State Assessment

### 2.1 Architecture Overview

| Layer | Technology | Status |
|-------|-----------|--------|
| UI Framework | SwiftUI (macOS 26+) | Functional |
| Speech Engine | SpeechTranscriber / SpeechAnalyzer | Functional |
| AI Engine | Apple Intelligence (Foundation Models) | Partially wired |
| Storage | iCloud Drive + SQLite | Functional |
| Concurrency | Swift Actors + @MainActor | Functional |

### 2.2 Critical Issues (Data Loss / Broken Functionality)

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| C1 | Description edits not persisted to database — lost on restart | TranscriptionViewModel.swift:993-1020 | Critical |
| C2 | `autoStartTranscription` setting stored but never read | SettingsView.swift:42 | Critical |
| C3 | `defaultLocale` setting stored but never applied — always defaults to en-US | SettingsView.swift:40, TranscriptionViewModel.swift:14 | Critical |
| C4 | `defaultExportFormat` setting stored but never referenced during export | SettingsView.swift:11 | High |
| C5 | `PersistedJobData.language` stores audio URL instead of locale identifier | PersistedJobData.swift:46 | Critical |
| C6 | Security-scoped resource access revoked after arbitrary 3-second delay — large files may fail | DropZoneView.swift:86-88 | Critical |
| C7 | Tags/topics never generated despite full AI implementation existing | AIService.swift:192-218 | High |
| C8 | Detected speakers never populated despite extraction code existing | AIService.swift:121-154 | High |
| C9 | AI-suggested filename feature fully implemented but never called | AIService.swift:158-187 | High |

### 2.3 High-Priority UX Issues

| # | Issue | Location |
|---|-------|----------|
| U1 | No view for processing/pending selected jobs — blank right pane | StandardView.swift:31-38 |
| U2 | No confirmation dialog for "Clear All" / "Clear Completed" / "Remove" — destructive actions proceed silently | HeaderView.swift:72-73, FileListView.swift:178 |
| U3 | Inconsistent file addition flows — company picker only triggers from "+" button, not drag-and-drop | DropZoneView.swift:83 vs FileListView.swift:51 |
| U4 | Family member delete does not refresh UI | MemoriesSettingsView.swift:146-149 |
| U5 | Chat stop button does not actually cancel AI generation | TranscriptView.swift:442-447 |
| U6 | Chat auto-save is conditional with no visual indicator | TranscriptView.swift:498 |
| U7 | No onboarding or first-run experience | ContentView.swift |
| U8 | "Start" button disabled with no explanation when transcription unavailable | HeaderView.swift:69 |

### 2.4 Polish & Interaction Gaps

| # | Issue | Location |
|---|-------|----------|
| P1 | Zero keyboard shortcuts defined for any action | App-wide |
| P2 | No context menu on transcript text (copy all, export, summarize selection) | TranscriptView.swift:188-193 |
| P3 | Three different rename entry points with inconsistent behavior | FileListView.swift:108, 137, 228 |
| P4 | No animations or transitions between states | StandardView.swift:22-44 |
| P5 | Inconsistent corner radii (6, 8, 12, 16 used across views) | Multiple files |
| P6 | Hard-coded colors with no shared theme/palette | Multiple files |
| P7 | No drag-and-drop support in Advanced mode when files exist | AdvancedView.swift |
| P8 | Duplicate SQLite connections in DatabaseService and MemoryService | DatabaseService.swift, MemoryService.swift |
| P9 | Excessive debug print statements throughout codebase | TranscriptionViewModel.swift:373-461 |

---

## 3. Competitive Landscape Analysis

### 3.1 Feature Comparison Matrix

| Capability | NitNab (Current) | Otter.ai | MacWhisper | Descript | Rev.com |
|-----------|-----------------|----------|------------|---------|---------|
| Per-file transcription | No (batch only) | Yes | Yes | Yes | Yes |
| Batch transcription | Yes | Yes (via meetings) | Yes (Pro) | Yes | Yes |
| Auto-summarization | Partial (button exists, not bulk) | Yes (auto after meetings) | Via AI prompts | No native | Yes (AI chat) |
| Bulk summarization | No | No | No | No | Yes (multi-file AI chat) |
| Speaker identification | Code exists, not wired | Weak (Speaker 1/2) | Weak | Good | Good (diarization) |
| Smart file naming | Code exists, not wired | Auto-named by meeting title | Manual | Project-based | Manual + keywords |
| Offline processing | Yes (on-device) | No | Yes | No | No |
| Privacy-first | Yes (Apple Intelligence) | No (cloud) | Yes (local Whisper) | No (cloud) | No (cloud) |
| Export formats | TXT, SRT, VTT, JSON, MD | TXT, DOCX, PDF, SRT | Multiple simultaneous | Timeline export | Multiple |
| macOS native | Yes | No (web/Electron) | Yes | Electron | No (web) |

### 3.2 Key Competitive Insights

**Otter.ai:**
- Summaries auto-generate after meetings and appear at the top of notes — users don't need to request them
- AI Chat spans the entire transcript library, not just individual files
- Weakness: speaker naming remains poor ("Speaker 1", "Speaker 2") — an opportunity for NitNab to differentiate
- File naming is automatic based on meeting calendar event title

**MacWhisper:**
- Batch transcription allows selecting multiple export formats simultaneously in the batch window
- Drag-and-drop multiple files opens a dedicated batch interface
- Clean, native macOS feel — described as "perfectly tailored for macOS, feeling like a native utility"
- Pro tier required for batch processing — NitNab could offer this in the base product
- Built-in audio player syncs with transcript for real-time verification

**Descript:**
- Text-based editing paradigm — edit media by editing transcript text
- Batch export by markers, line breaks, or compositions
- Strong multi-format workflow integrations (Adobe, Final Cut, Logic)
- Pricing model penalizes multi-file workflows — NitNab's offline model avoids this

**Rev.com:**
- Multi-file AI chat for cross-file analysis and summarization
- Strong speaker diarization (though not identification by voice)
- Speaker label editing with merge functionality for duplicate speakers
- Legal-grade security and encryption — relevant for professional users

### 3.3 NitNab's Competitive Advantages

1. **Fully on-device** — no cloud dependency, no per-minute pricing, complete privacy
2. **Apple Intelligence integration** — native Foundation Models for summarization
3. **Company context system** — vocabulary and people databases for accuracy
4. **macOS native** — true SwiftUI app, not Electron/web wrapper
5. **iCloud sync** — structured folder output for each transcription

### 3.4 Competitive Gaps to Close

1. Per-file transcription is table stakes — every competitor offers it
2. Auto-summarization should be automatic, not manual — follow Otter.ai's lead
3. Speaker identification must be wired up — the code exists but isn't connected
4. Smart naming should combine date + AI description + speakers — no competitor does this well

---

## 4. Platform Alignment: macOS 26 Tahoe & Liquid Glass

### 4.1 Liquid Glass Design Language

Apple's Liquid Glass is the most significant design evolution since iOS 7, introduced at WWDC 2025. Key characteristics:

- **Translucent material** that reflects and refracts surroundings
- **Real-time light bending** (lensing) instead of traditional blur
- **Specular highlights** responding to device motion
- **Adaptive shadows** and interactive behaviors
- **Completely transparent menu bar** on macOS Tahoe

**Impact on NitNab:**

| Element | Current State | Liquid Glass Recommendation |
|---------|--------------|---------------------------|
| Toolbar | Standard AppKit toolbar | Recompile with Xcode 26 for automatic Liquid Glass adoption |
| Sidebar | Custom styled VStack | Use NavigationSplitView for native Liquid Glass sidebar |
| File list | Custom list with hard-coded colors | Adopt system list styles — Liquid Glass materials auto-apply |
| Drop zone | Custom rounded rectangle | Replace hard-coded opacity backgrounds with system materials |
| Settings | TabView | Will auto-adopt Liquid Glass tab styling |

**Action Required:**
- Recompiling with Xcode 26 gives standard controls Liquid Glass automatically
- Remove hard-coded `Color.blue.opacity(0.05)` backgrounds in favor of system materials
- Replace custom corner radii with system-defined values
- Test across Light, Dark, and Increased Contrast appearances

### 4.2 Apple HIG Alignment

**Sidebars:** Apple HIG states sidebars should appear on the leading side and provide navigation between sections. NitNab's file list functions as a sidebar but is implemented as a custom VStack inside an HSplitView. Recommendation: adopt `NavigationSplitView` for proper sidebar behavior.

**Split Views:** The HIG specifies split views should manage multiple adjacent panes. NitNab uses HSplitView correctly but lacks proper minimum width constraints and responsive behavior.

**Progress Indicators:** The HIG emphasizes that progress indicators must "let people know that your app isn't stalled." NitNab shows per-row progress but has no global indicator for batch operations and no feedback when the right pane is blank during processing.

### 4.3 Foundation Models Framework Integration

The Foundation Models framework (WWDC25) provides on-device AI capabilities:

- **Summarization** — optimized for the on-device model
- **Text extraction** — structured Swift types as responses
- **Classification** — topic extraction and categorization
- **Guided generation** — structured output without JSON parsing

NitNab already uses `LanguageModelSession` from this framework in AIService.swift. The opportunity is to wire up the existing but disconnected functions: `extractTopics()`, `extractNames()`, and `suggestFileName()`.

---

## 5. Feature Plan: Three Pillars of Improvement

### 5.1 Feature 1: Per-File Transcription

**Competitive Context:** Every competitor (Otter, MacWhisper, Descript, Rev) offers per-file transcription. NitNab's batch-only model is a significant friction point.

**Design Principle (MacWhisper pattern):** MacWhisper shows that the native macOS approach is drag-and-drop a file, transcription begins. The batch window is a separate, explicit mode. NitNab should follow this pattern.

#### Implementation Plan

**A. ViewModel Changes** (`TranscriptionViewModel.swift`)

```
New method: transcribeSingleJob(_ jobId: UUID)
- Extract the single-job processing logic from startProcessing()
- Set only the target job to .processing (not all pending jobs)
- Other pending jobs remain untouched for later batch processing
- Reuse existing processJob(id:) which already handles one job
- Add queue management: if a transcription is already running,
  enqueue the new request and process sequentially
```

**B. File Row Button** (`FileListView.swift`)

```
For jobs with status == .pending:
- Show an inline "Transcribe" button (waveform.badge.plus icon)
- On click: call viewModel.transcribeSingleJob(job.id)
- While processing: show the existing progress bar
- Animate transition from button to progress bar
```

**C. Pending State View** (New: `PendingJobView.swift`)

```
When a pending job is selected, show in the right pane:
- File metadata (name, duration, format, size)
- Audio waveform preview (if feasible)
- Prominent "Start Transcription" call-to-action button
- Locale picker (pre-filled from settings)
- Company picker (pre-filled if already assigned)
```

**D. Auto-Start Option** (wire existing setting)

```
Fix the existing autoStartTranscription setting (C2 above):
- When enabled: automatically call transcribeSingleJob()
  after each file is added via addFiles() or addFilesDirectly()
- This delivers MacWhisper-style "drop and go" behavior
```

**E. Header Changes** (`HeaderView.swift`)

```
- Rename "Start" to "Transcribe All" for clarity
- Add count badge: "Transcribe All (5)"
- Disable while any transcription is running
- Show which job is currently processing in a subtitle
```

**F. Concurrency Model**

```
TranscriptionService already guards against concurrent analyzers.
Implementation approach:
- Maintain a FIFO queue of job IDs to process
- Process one at a time, sequentially
- "Transcribe All" adds all pending to the queue
- "Transcribe" (per-file) adds one to the front of the queue
- Cancel cancels the current job and clears the queue
```

#### Revised from Original Plan Based on Research

- **Added:** Auto-start setting wiring (discovered broken during audit)
- **Added:** Pending state view for right pane (blank pane was a UX gap found in audit)
- **Added:** FIFO queue model (inspired by MacWhisper's sequential batch approach)
- **Changed:** Per-file button placement refined — both in row AND in detail pane

---

### 5.2 Feature 2: Bulk Summarization

**Competitive Context:** Otter.ai auto-generates summaries after every meeting. Rev.com allows multi-file AI chat. No competitor offers explicit "bulk summarize" — this is a differentiation opportunity.

**Design Principle (Otter pattern):** Summaries should be automatic by default, with manual trigger as fallback. The summary should appear prominently — not buried in a tab.

#### Implementation Plan

**A. Data Model Changes** (`TranscriptionJob.swift`)

```
Add to TranscriptionJob:
- summary: String?           // AI-generated summary text
- summaryGeneratedAt: Date?  // Timestamp for staleness detection
- summaryStatus: SummaryStatus  // .none | .generating | .completed | .failed
```

**B. Database Migration** (`DatabaseService.swift`)

```
Add columns to transcription_jobs table:
- summary TEXT
- summary_generated_at REAL
- summary_status TEXT DEFAULT 'none'
Migration: ALTER TABLE IF NOT EXISTS pattern
```

**C. ViewModel Methods** (`TranscriptionViewModel.swift`)

```
New methods:
- summarizeSingleJob(_ jobId: UUID)
  - Guard: job must be .completed with a transcript
  - Call AIService.generateSummary(transcript:)
  - Also call AIService.extractTopics() and AIService.extractNames()
  - Store summary, tags, and detectedSpeakers on the job
  - Persist to database and to AI Summary/summary.txt

- summarizeAllCompleted()
  - Filter: completed jobs where summary == nil
  - Process sequentially (Foundation Models is on-device, sequential is safer)
  - Update progress: "Summarizing 3 of 12..."
  - Skip jobs that already have summaries

- autoSummarizeAfterTranscription(_ jobId: UUID)
  - Called automatically at the end of processJob()
  - Only if user has enabled auto-summarize in settings
```

**D. Bulk Summarize Button** (`HeaderView.swift`)

```
Add "Summarize All" button:
- Icon: text.badge.star or sparkles
- Only enabled when unsummarized completed jobs exist
- Shows count: "Summarize All (7)"
- During operation: shows progress "Summarizing 3 of 7..."
- Can be cancelled
```

**E. Summary Display** (`TranscriptView.swift`)

```
Move summary to prominent position:
- Show summary card ABOVE the transcript tabs (not inside a tab)
- Card shows: summary text, generated timestamp, "Regenerate" button
- If no summary: show "Generate Summary" button in the card space
- Collapsible with disclosure triangle for users who prefer transcript-first

Wire up existing extractTopics() and extractNames():
- After summarization, auto-populate tags and detectedSpeakers
- Tags appear in the Advanced mode tag cloud (currently always empty)
- Speaker names appear in file metadata
```

**F. File Row Indicators** (`FileListView.swift`)

```
Add summary status to FileRowView:
- Small icon: sparkles (summarized) or empty (not yet)
- Tooltip: "AI Summary available" or "Not yet summarized"
```

**G. Settings** (`SettingsView.swift`)

```
Add to General tab:
- Toggle: "Auto-summarize after transcription" (default: on)
- Toggle: "Auto-extract topics and speakers" (default: on)
```

#### Revised from Original Plan Based on Research

- **Added:** Auto-summarize after transcription (inspired by Otter.ai's automatic approach)
- **Added:** Wire up extractTopics() and extractNames() alongside summarization (audit found these disconnected)
- **Changed:** Summary placement moved above tabs, not inside a tab (Otter shows summary at top of notes)
- **Added:** Tag cloud population (audit found tags were always empty due to disconnected code)
- **Added:** Speaker name population (audit found detectedSpeakers never populated)

---

### 5.3 Feature 3: Smart File Renaming

**Competitive Context:** No competitor does smart naming well. Otter uses meeting calendar titles. MacWhisper and Rev use original filenames. Descript uses project names. NitNab can differentiate by offering AI-powered multi-component naming.

**Design Principle:** Give the user a formula they configure once, then apply automatically. Show a preview before committing. Never rename silently without consent.

#### Implementation Plan

**A. Naming Preferences Model** (New: `NamingPreferences.swift`)

```swift
struct NamingPreferences: Codable {
    var includeDate: Bool = true
    var includeDescription: Bool = true
    var includeSpeakerNames: Bool = true

    var dateFormat: DateFormatOption = .iso       // 2026-02-15
    var descriptionStyle: DescriptionStyle = .short  // "Q1 Budget Review"
    var nameStyle: NameStyle = .firstNames        // "Sarah, Mike"
    var separator: String = " — "                 // "2026-02-15 — Q1 Budget Review — Sarah, Mike"
    var maxLength: Int = 80

    var autoRenameAfterTranscription: Bool = false  // Off by default (never rename silently)
}

enum DateFormatOption: String, Codable, CaseIterable {
    case iso = "yyyy-MM-dd"           // 2026-02-15
    case natural = "MMM d, yyyy"      // Feb 15, 2026
    case compact = "MM-dd-yy"         // 02-15-26
}

enum DescriptionStyle: String, Codable, CaseIterable {
    case short = "Short (3-5 words)"
    case medium = "Medium (1 sentence)"
}

enum NameStyle: String, Codable, CaseIterable {
    case firstNames = "First names only"     // Sarah, Mike
    case fullNames = "Full names"            // Sarah Johnson, Mike Chen
    case initialsOnly = "Initials"           // SJ, MC
}
```

**B. AI Name Generation** (`AIService.swift`)

```
Enhance existing suggestFileName() to accept NamingPreferences:
- Use extractNames() for speaker identification
- Use a short summarization prompt for description
- Use job.audioFile metadata or job.createdAt for date
- Assemble components based on user preferences
- Respect maxLength with intelligent truncation

Example outputs:
  Date + Description + Names: "2026-02-15 — Q1 Budget Review — Sarah, Mike"
  Date + Description:         "2026-02-15 — Q1 Budget Review"
  Description + Names:        "Q1 Budget Review — Sarah, Mike"
  Description only:           "Q1 Budget Review"
```

**C. Smart Rename Sheet** (New: `SmartRenameSheet.swift`)

```
A sheet presented after transcription or on-demand:
- Preview of the generated name at the top (large, editable text field)
- Toggle switches for each component (date, description, speakers)
- Toggling a component live-updates the preview
- "Apply" button saves as customName
- "Skip" dismisses without renaming
- "Always use these settings" checkbox → saves to NamingPreferences
```

**D. Post-Transcription Flow** (`TranscriptionViewModel.swift`)

```
After processJob() completes (and after auto-summarize if enabled):
1. If autoRenameAfterTranscription is ON:
   - Generate name silently using saved preferences
   - Apply as customName
   - Show subtle notification in file row (brief highlight animation)
2. If autoRenameAfterTranscription is OFF:
   - Show SmartRenameSheet with the generated suggestion
   - User can accept, modify, or skip
```

**E. Bulk Rename** (`TranscriptionViewModel.swift`)

```
New method: bulkSmartRename()
- Filter: completed jobs where renamingApplied == false
- For each: generate name from preferences, apply
- Show progress: "Renaming 5 of 12..."
- Present a review sheet showing all proposed renames before applying
```

**F. Settings Integration** (`SettingsView.swift`)

```
New "File Naming" section in General tab:
- Component toggles (date, description, speakers)
- Date format picker
- Description style picker
- Name style picker
- Separator picker
- Auto-rename toggle
- Live preview showing example output:
  "2026-02-15 — Q1 Budget Review — Sarah, Mike"
  Updates in real-time as user toggles components
```

**G. Context Menu Integration** (`FileListView.swift`)

```
Add to existing context menu:
- "Smart Rename..." → opens SmartRenameSheet for that job
- Only available for completed jobs with transcripts
```

#### Revised from Original Plan Based on Research

- **Added:** Live preview in settings and rename sheet (no competitor shows this)
- **Added:** Bulk rename with review sheet (never rename silently in bulk)
- **Changed:** Auto-rename defaults to OFF (user consent is paramount per HIG principles)
- **Added:** Name style options (first names, full names, initials) based on Rev.com's speaker label flexibility
- **Added:** Context menu integration for discoverability (audit found missing context menus)

---

## 6. UX Polish & Usability Recommendations

### 6.1 Keyboard Shortcuts (Missing Entirely)

Every professional macOS app provides keyboard shortcuts. NitNab has zero.

| Action | Shortcut | Rationale |
|--------|----------|-----------|
| Add files | Cmd+O | Standard macOS file open |
| Transcribe selected | Cmd+Return | Natural "go" action |
| Transcribe all | Cmd+Shift+Return | Batch variant |
| Summarize selected | Cmd+S (in transcript context) | Or Cmd+Shift+S |
| Copy transcript | Cmd+Shift+C | When transcript view is active |
| Export | Cmd+E | Standard export |
| Search (Advanced) | Cmd+F | Standard search |
| Toggle Standard/Advanced | Cmd+1 / Cmd+2 | Mode switching |
| Select previous/next file | Up/Down arrows | File navigation |
| Delete selected | Cmd+Delete | With confirmation dialog |
| Rename | Return (when file selected) | Finder convention |
| Settings | Cmd+, | Standard macOS settings |

### 6.2 State Management — Eliminate Blank Panes

Current state: selecting a processing or pending job shows nothing in the right pane.

**Required views:**

| Job Status | Right Pane Content |
|-----------|-------------------|
| No selection | Welcome/drop zone with instructions |
| Pending | File metadata + "Start Transcription" CTA |
| Processing | Live progress bar + elapsed time + cancel button |
| Completed | Transcript view (existing) |
| Failed | Error details + "Retry" button (partially exists) |

### 6.3 Confirmation Dialogs

Add confirmation for all destructive actions:

- **Remove job:** "Remove 'filename'? This will delete the audio file and any transcripts from iCloud."
- **Clear completed:** "Remove N completed transcriptions? This cannot be undone."
- **Clear all:** "Remove ALL transcriptions? This will delete all files and data. This cannot be undone."

Use `.confirmationDialog` or `.alert` with destructive role styling.

### 6.4 Consistent File Addition Flow

Unify the two file addition paths:

1. Both drag-and-drop AND file picker should trigger duplicate detection
2. Both should offer company picker (or make it optional via settings)
3. Both should support the auto-start-transcription setting

### 6.5 Design System

Create a shared constants file for visual consistency:

```swift
enum DesignSystem {
    enum CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
    }

    enum Spacing {
        static let compact: CGFloat = 4
        static let standard: CGFloat = 8
        static let relaxed: CGFloat = 16
    }
}
```

Replace all hard-coded values across the codebase.

### 6.6 Remove Debug Artifacts

- Remove all `print("emoji STEP N: ===== ...")` statements from TranscriptionViewModel
- Replace with `os.Logger` for structured logging that can be filtered in Console.app
- Remove or convert diagnostic shell scripts at repo root

---

## 7. Accessibility & Inclusivity

### 7.1 VoiceOver Support

| Area | Current State | Recommendation |
|------|--------------|----------------|
| File list items | Basic label | Add `accessibilityLabel` with status: "Meeting recording, completed, 5 minutes" |
| Progress indicators | No announcement | Add `accessibilityValue` for progress percentage |
| Buttons | Some have labels | Audit all buttons for descriptive `accessibilityLabel` |
| Status changes | Silent | Use `AccessibilityNotification.Announcement` for status transitions |
| Tab navigation | Not configured | Ensure proper tab order in TranscriptView tab bar |

### 7.2 Keyboard Navigation

- Ensure all interactive elements are focusable via Tab key
- File list should support arrow key navigation
- Transcript view tabs should support left/right arrow switching
- All sheets/dialogs should have proper `.cancelAction` and `.defaultAction` key equivalents

### 7.3 Visual Accessibility

- Test all views with "Increase Contrast" setting enabled
- Verify Liquid Glass materials remain readable with "Reduce Transparency"
- Ensure tag cloud colors meet WCAG 2.1 AA contrast ratios
- Support Dynamic Type for any custom text sizing

---

## 8. Implementation Roadmap

### Phase 1: Foundation & Bug Fixes (Week 1)

**Goal:** Fix critical bugs and establish infrastructure for new features.

| Task | Priority | Effort |
|------|----------|--------|
| Fix C1: Persist description edits to database | Critical | 1 hour |
| Fix C2: Wire autoStartTranscription setting | Critical | 2 hours |
| Fix C3: Wire defaultLocale setting | Critical | 1 hour |
| Fix C4: Wire defaultExportFormat setting | High | 1 hour |
| Fix C5: Fix PersistedJobData.language bug | Critical | 30 min |
| Fix C6: Replace 3-second security scope timer with completion handler | Critical | 2 hours |
| Fix U2: Add confirmation dialogs for destructive actions | High | 2 hours |
| Fix U3: Unify file addition flows | High | 3 hours |
| Remove debug print statements (P9) | Medium | 1 hour |
| Create DesignSystem constants file (P5, P6) | Medium | 2 hours |

### Phase 2: Per-File Transcription (Week 2)

**Goal:** Enable transcribe-on-demand for individual files.

| Task | Priority | Effort |
|------|----------|--------|
| Implement FIFO transcription queue in ViewModel | High | 4 hours |
| Add transcribeSingleJob() method | High | 2 hours |
| Add per-row "Transcribe" button in FileRowView | High | 2 hours |
| Create PendingJobView for right pane | High | 3 hours |
| Create ProcessingJobView for right pane | High | 2 hours |
| Update HeaderView with "Transcribe All (N)" | Medium | 1 hour |
| Wire auto-start transcription setting | Medium | 1 hour |
| Add keyboard shortcuts (Cmd+Return, Cmd+O) | Medium | 2 hours |

### Phase 3: Bulk Summarization (Week 3)

**Goal:** Auto-summarize completed transcriptions with Apple Intelligence.

| Task | Priority | Effort |
|------|----------|--------|
| Add summary fields to TranscriptionJob model | High | 1 hour |
| Database migration for summary columns | High | 2 hours |
| Implement summarizeSingleJob() | High | 3 hours |
| Wire up extractTopics() and extractNames() | High | 2 hours |
| Implement summarizeAllCompleted() | High | 2 hours |
| Add summary card above transcript tabs | High | 3 hours |
| Add "Summarize All" button to HeaderView | Medium | 1 hour |
| Add summary indicator to FileRowView | Medium | 1 hour |
| Add auto-summarize setting | Medium | 1 hour |
| Populate tag cloud from extracted topics | Medium | 2 hours |

### Phase 4: Smart File Renaming (Week 4)

**Goal:** AI-powered file naming from date, description, and speakers.

| Task | Priority | Effort |
|------|----------|--------|
| Create NamingPreferences model | High | 1 hour |
| Enhance AIService.suggestFileName() | High | 3 hours |
| Create SmartRenameSheet view | High | 4 hours |
| Add naming preferences to SettingsView | High | 3 hours |
| Implement post-transcription rename flow | High | 2 hours |
| Implement bulkSmartRename() with review sheet | Medium | 3 hours |
| Add "Smart Rename..." to context menu | Medium | 1 hour |

### Phase 5: Polish & Accessibility (Week 5)

**Goal:** Liquid Glass alignment, accessibility, and final polish.

| Task | Priority | Effort |
|------|----------|--------|
| Adopt NavigationSplitView for Liquid Glass sidebar | High | 4 hours |
| Replace hard-coded colors with system materials | High | 3 hours |
| Add all keyboard shortcuts | High | 3 hours |
| VoiceOver audit and accessibility labels | High | 4 hours |
| Add state transitions with animations | Medium | 3 hours |
| Add onboarding/first-run experience | Medium | 4 hours |
| Test across Light/Dark/High Contrast | Medium | 2 hours |
| Final code cleanup and logging | Low | 2 hours |

---

## 9. Appendix: Detailed Issue Registry

### Code-Level References

All issues reference specific file locations in the NitNab codebase:

| File | Issues Found |
|------|-------------|
| `TranscriptionViewModel.swift` | C1, C2, C3, U8, P9 (debug prints), description persistence, settings not wired |
| `SettingsView.swift` | C2, C3, C4 (three settings stored but never read) |
| `PersistedJobData.swift` | C5 (language field stores URL) |
| `DropZoneView.swift` | C6 (3-second timer), U3 (no company picker path) |
| `AIService.swift` | C7, C8, C9 (three AI functions implemented but not wired) |
| `StandardView.swift` | U1 (blank right pane for pending/processing) |
| `AdvancedView.swift` | U1, P7 (no drop target when files exist) |
| `HeaderView.swift` | U2 (no confirmation for clear), U8 (disabled with no explanation) |
| `FileListView.swift` | U2, U3, P3 (three rename paths) |
| `TranscriptView.swift` | U5 (chat stop broken), U6 (conditional save), P2 (no context menu) |
| `MemoriesSettingsView.swift` | U4 (family delete no refresh) |
| `ContentView.swift` | U7 (no onboarding) |
| `DatabaseService.swift` | P8 (duplicate connections) |
| `MemoryService.swift` | P8 (duplicate connections) |
| `TagCloudView.swift` | P6 (opacity issues) |

### Research Sources

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Apple Liquid Glass Announcement](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
- [Foundation Models Framework — WWDC25](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Otter.ai Review (2026)](https://tldv.io/blog/otter-ai-review/)
- [MacWhisper Batch Transcription](https://macwhisper.helpscoutdocs.com/article/19-batch-transcription)
- [Descript Review (2025)](https://www.castmagic.io/software-review/descript)
- [Rev.com Transcription Editor](https://support.rev.com/hc/en-us/articles/29824992702989-Transcription-Editor)
- [Liquid Glass in Swift — Best Practices](https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo)

---

*End of document.*
