# Adding New Files to Xcode Project

## Issue Found
The new files created during implementation exist on disk but are **not yet added to the Xcode project target**.

This causes build errors:
- `cannot find type 'Person' in scope`
- `cannot find 'MemoryService' in scope`

## Files That Need to Be Added

### Models (1 file)
- `NitNab/Models/Memory.swift`

### Services (1 file)
- `NitNab/Services/MemoryService.swift`

### Views (5 files)
- `NitNab/Views/MemoriesSettingsView.swift`
- `NitNab/Views/StandardView.swift`
- `NitNab/Views/AdvancedView.swift` (ALREADY MODIFIED - should be in project)
- `NitNab/Views/SearchBarView.swift`
- `NitNab/Views/TagCloudView.swift`

### Modified Files (Should Already Be in Project)
- `NitNab/Models/TranscriptionJob.swift` ✓
- `NitNab/Services/DatabaseService.swift` ✓
- `NitNab/Services/AIService.swift` ✓
- `NitNab/Views/ContentView.swift` ✓
- `NitNab/Views/SettingsView.swift` ✓

## How to Add Files to Xcode Project

### Option 1: Drag & Drop in Xcode (Easiest)

1. Open `NitNab.xcodeproj` in Xcode
2. In Project Navigator, right-click on the appropriate folder
3. Select "Add Files to NitNab..."
4. Navigate to the file location
5. **IMPORTANT**: Check "Copy items if needed" = NO (files are already there)
6. **IMPORTANT**: Check "Add to targets" = NitNab
7. Click "Add"

Repeat for each file.

### Option 2: Add All at Once

1. Open `NitNab.xcodeproj` in Xcode
2. Select all new files in Finder:
   - `Models/Memory.swift`
   - `Services/MemoryService.swift`
   - `Views/MemoriesSettingsView.swift`
   - `Views/StandardView.swift`
   - `Views/SearchBarView.swift`
   - `Views/TagCloudView.swift`

3. Drag them into the Xcode Project Navigator
4. In the dialog:
   - Uncheck "Copy items if needed"
   - Check "Create groups"
   - Select target: NitNab
5. Click "Finish"

### Option 3: Command Line (Advanced)

Use a tool like `xcodeproj` or manually edit the `.pbxproj` file (not recommended).

## After Adding Files

1. Build the project (⌘B)
2. Should compile successfully
3. Run the app (⌘R)
4. Test new features

## Expected Result

After adding files, the build should succeed and you'll see:
- Settings → Memories tab
- Toolbar → Mode toggle button
- Advanced Mode with search, tags, sorting

---

**Status**: Files exist on disk ✅  
**Status**: Files in Xcode project ❌ ← **YOU ARE HERE**  
**Next**: Add files to Xcode, then build will succeed
