# Chunk 6: Company Workflow - Implementation Summary

## Status: Foundation Complete ✅

All prerequisites for Chunk 6 are in place. The company workflow integration is ready to be wired into the transcription process.

## What's Already Built (From Previous Chunks)

### Database Layer ✅ (Chunk 1)
- `TranscriptionJob` has `companyId`, `attendeeIds`, `detectedSpeakers`, `tags`, `modifiedAt`
- Database schema includes all company-related columns
- JSON helper methods for encoding/decoding arrays

### Memory Service ✅ (Chunk 2)
- `buildCustomVocabulary(for:)` - Creates vocabulary from company people + terms
- `getKnownPeople(for:)` - Returns people for a company
- Full CRUD for companies and people

### AI Service ✅ (Chunk 5)
- `extractNames(transcript:knownPeople:)` - Extract names with known people context
- `buildAIContext()` - Get user context
- All methods ready to use company data

## What Needs Integration

### Task 6.1: Company Picker UI
**Location**: `FileListView.swift` / `FileRowView.swift`

Add to context menu:
```swift
Button("Assign to Company...") {
    viewModel.showCompanyPicker(for: job)
}
```

Show company badge if assigned:
```swift
if let companyId = job.companyId {
    // Show company name badge
}
```

### Task 6.2: TranscriptionViewModel Updates
**Location**: `TranscriptionViewModel.swift`

Add properties:
```swift
@Published var showingCompanyPicker = false
@Published var jobToAssignCompany: TranscriptionJob?
@Published var companies: [Company] = []
```

Add methods:
```swift
func assignCompany(_ companyId: UUID, to job: TranscriptionJob)
func loadCompanies() async
func processJobWithCompany(job: TranscriptionJob) async
```

### Task 6.3: TranscriptionService Enhancement
**Location**: `TranscriptionService.swift`

Update transcribe method signature:
```swift
func transcribe(
    audioURL: URL,
    locale: Locale,
    customVocabulary: [String] = [],  // NEW
    progressHandler: @escaping (Double) -> Void
) async throws -> TranscriptionResult
```

**Note**: `SFSpeechRecognizer` on macOS may have limited custom vocabulary support. Alternative: post-processing with AI name correction.

### Task 6.4: Attendee Matching
**Location**: `TranscriptionViewModel.swift`

After transcription completes:
```swift
if let companyId = job.companyId,
   let speakers = job.detectedSpeakers {
    let knownPeople = await MemoryService.shared.getKnownPeople(for: companyId)
    let matches = matchSpeakersTopeople(speakers, knownPeople)
    job.attendeeIds = matches.map { $0.id }
}
```

### Task 6.5: Database Operations
**Location**: `DatabaseService.swift`

Update `insertTranscription` and `updateJob` to handle:
- `company_id` (UUID as string)
- `attendee_ids` (JSON array of UUID strings)
- `speakers` (JSON array of strings)
- `tags` (JSON array of strings)
- `modified_at` (ISO8601 date string)

Use existing JSON helper methods from Chunk 1.

## Implementation Approach

Since all the building blocks exist:

1. **UI Integration** (30 min)
   - Add company picker sheet to FileListView
   - Add company badge display to FileRowView
   - Wire up to ViewModel

2. **ViewModel Updates** (30 min)
   - Add company assignment logic
   - Integrate custom vocabulary before transcription
   - Add attendee matching after transcription

3. **Service Integration** (30 min)
   - Pass custom vocabulary to TranscriptionService
   - Update DatabaseService save/load for company fields

**Total Estimated Time**: 1.5 hours (vs 8-10 hours estimated)

## Why It's Faster

- Database schema already exists (Chunk 1)
- MemoryService methods already built (Chunk 2)
- AI extraction methods already built (Chunk 5)
- Just wiring existing pieces together

## Testing Checklist

- [ ] Can assign a transcription to a company
- [ ] Company name shows in file list
- [ ] Custom vocabulary used during transcription
- [ ] Names detected and matched to known people
- [ ] Company assignment persists in database
- [ ] Can reassign to different company
- [ ] Can clear company assignment

## Notes

- Custom vocabulary in `SFSpeechRecognizer` may require iOS/macOS 15+
- If unavailable, fallback to AI-powered name correction post-transcription
- This approach actually works better since AI can understand context

---

**Status**: Ready for implementation  
**Difficulty**: Low (integration only)  
**Risk**: Low (all components tested independently)
