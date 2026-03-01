# Company Assignment Persistence Fix ✅

**Date**: October 10, 2025  
**Status**: ✅ **FIXED AND VERIFIED**

---

## Problem

Company assignments were not persisting when closing and reopening the app. After assigning a company to a file, restarting the app would show "No assignment."

---

## Root Cause

The `parseTranscriptionJob()` function in `DatabaseService.swift` was **not reading the `company_id` column** from the database when loading jobs at app startup.

### What Was Happening

**Writing (Save)** ✅ Working correctly:
```swift
// In updateJob() - company_id was being saved
if let companyId = job.companyId {
    sqlite3_bind_text(statement, 13, companyId.uuidString, ...)
}
```

**Reading (Load)** ❌ Missing:
```swift
// In parseTranscriptionJob() - company_id was NOT being read!
// Missing:
//   - Read from column 23
//   - Parse as UUID
//   - Pass to TranscriptionJob initializer
```

---

## Solution

Updated `parseTranscriptionJob()` to read and parse the `company_id` column from the database.

### Code Changes

**File**: `DatabaseService.swift`  
**Function**: `parseTranscriptionJob()`  
**Lines**: 799-832

#### Added Code

```swift
// Parse company_id
var companyId: UUID?
if let companyIdString = sqlite3_column_text(statement, 23) {
    companyId = UUID(uuidString: String(cString: companyIdString))
}
```

#### Updated Job Reconstruction

```swift
// Reconstruct TranscriptionJob
let job = TranscriptionJob(
    id: id,
    audioFile: audioFile,
    status: status,
    progress: progress,
    result: result,
    error: error,
    createdAt: createdAt,
    completedAt: completedAt,
    customName: customName,
    description: description,
    folderPath: folderPath,
    companyId: companyId  // ← Added this!
)
```

---

## Database Schema

The database table already had the `company_id` column:

```sql
CREATE TABLE transcriptions (
    ...
    company_id TEXT,  -- Column 23
    ...
);
```

**Column Index**: 23 (0-based indexing)

---

## Technical Details

### Column Order in SELECT *

```
 0: id
 1: folder_name
 2: folder_path
 3: audio_filename
 4: audio_path
 5: audio_format
 6: transcript_path
 7: transcript_text
 8: summary_path
 9: chat_path
10: duration
11: file_size
12: word_count
13: character_count
14: confidence
15: language
16: created_at
17: completed_at
18: status
19: progress
20: error
21: custom_name
22: description
23: company_id  ← This was missing!
24: attendee_ids
25: speakers
26: tags
27: modified_at
```

### Reading the Column

```swift
// Column 23 contains company_id as TEXT (UUID string)
if let companyIdString = sqlite3_column_text(statement, 23) {
    // Convert string to UUID
    companyId = UUID(uuidString: String(cString: companyIdString))
}
```

### Passing to Initializer

The `TranscriptionJob` initializer already had a `companyId` parameter, we just weren't using it:

```swift
init(
    id: UUID,
    audioFile: AudioFile,
    status: TranscriptionStatus,
    progress: Double,
    result: TranscriptionResult?,
    error: String?,
    createdAt: Date,
    completedAt: Date?,
    customName: String?,
    description: String?,
    folderPath: String?,
    companyId: UUID? = nil  // ← This parameter existed!
)
```

---

## Testing

### Before Fix
1. Assign company to file ✅
2. Company shows in UI ✅
3. Close app
4. Reopen app
5. ❌ Company assignment is gone

### After Fix
1. Assign company to file ✅
2. Company shows in UI ✅
3. Close app
4. Reopen app
5. ✅ Company assignment persists!

---

## Verification Steps

### Test 1: New Assignment
1. Start app
2. Assign company to a file
3. Verify it shows in UI
4. Close app completely (Cmd+Q)
5. Reopen app
6. ✅ Company assignment still there

### Test 2: Multiple Files
1. Assign different companies to multiple files
2. Close app
3. Reopen app
4. ✅ All assignments persist correctly

### Test 3: Null Assignment
1. File with no company assignment
2. Close and reopen app
3. ✅ Still shows no assignment (NULL preserved)

### Test 4: Change Assignment
1. Assign company A to file
2. Close and reopen app
3. Verify company A persists
4. Change to company B
5. Close and reopen app
6. ✅ Company B persists (not company A)

---

## Code Quality

### Codacy Analysis ✅
**File Analyzed**: DatabaseService.swift

**Results**:
- ✅ 0 Security Issues
- ✅ 0 Code Quality Issues
- ✅ 0 Vulnerabilities
- ✅ Clean code standards met

### Build Status ✅
- Build: **SUCCESS**
- App: **RUNNING**
- Tests: Persistence verified

---

## Related Code

### Save Path (Already Working)

```swift
// In updateJob() - Lines 609-617
// Bind company_id (parameter 13)
if let companyId = job.companyId {
    sqlite3_bind_text(statement, 13, companyId.uuidString, -1, SQLITE_TRANSIENT)
} else {
    sqlite3_bind_null(statement, 13)
}

// Bind job ID (parameter 14 - WHERE clause)
sqlite3_bind_text(statement, 14, job.id.uuidString, -1, SQLITE_TRANSIENT)
```

### Load Path (Now Fixed)

```swift
// In parseTranscriptionJob() - Lines 799-832
// Parse company_id
var companyId: UUID?
if let companyIdString = sqlite3_column_text(statement, 23) {
    companyId = UUID(uuidString: String(cString: companyIdString))
}

// Include in job reconstruction
let job = TranscriptionJob(
    ...
    companyId: companyId
)
```

---

## Why This Wasn't Caught Earlier

1. **Write worked**: Company assignments were being saved to database
2. **UI showed it**: During the session, assignments were in memory
3. **Only failed on reload**: Problem only appeared after app restart
4. **Database had the data**: If you inspected the database, company_id was there

The issue was purely in the **reading/loading** code, not the writing code.

---

## Lessons Learned

### Always Verify Both Paths
- ✅ Write path (save)
- ✅ Read path (load)
- ✅ Round-trip test (save + restart + load)

### Database Column Reading
- Must read ALL columns that are being written
- Column indices must match schema order
- NULL handling is important

### Testing After Restart
- In-memory state can hide persistence bugs
- Always test: Save → Quit → Relaunch → Verify

---

## Future Safeguards

### Potential Improvements
- [ ] Unit tests for database round-trips
- [ ] Verify all columns are read in SELECT *
- [ ] Integration test: Save → Load → Compare
- [ ] Schema validation on startup
- [ ] Column count assertion

---

## Summary

✅ **Bug identified**: company_id not being read from database  
✅ **Root cause found**: Missing column read in parseTranscriptionJob()  
✅ **Fix implemented**: Added company_id parsing  
✅ **Code verified**: Codacy clean, builds successfully  
✅ **Persistence working**: Company assignments now persist!

**Status**: Company assignments now survive app restarts! 🎉

---

## Quick Reference

**Problem**: Company assignments lost on app restart  
**Cause**: Not reading company_id column from database  
**Fix**: Added company_id parsing in parseTranscriptionJob()  
**File**: DatabaseService.swift, lines 799-832  
**Result**: Persistence now works correctly ✅
