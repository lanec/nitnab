# Setting Up Test Targets in Xcode

## Issue
The test files have been created but need to be added to test targets in the Xcode project.

## Created Test Files

**Unit Tests** (need to be in NitNabTests target):
- `NitNabTests/TestHelpers.swift`
- `NitNabTests/NitNabTests.swift`
- `NitNabTests/DatabaseServiceTests.swift`
- `NitNabTests/AIServiceTests.swift`
- `NitNabTests/AudioFileManagerTests.swift`
- `NitNabTests/PersistenceServiceTests.swift`
- `NitNabTests/TranscriptionWorkflowTests.swift`

**UI Tests** (need to be in NitNabUITests target):
- `NitNabUITests/NitNabUITests.swift`

## Steps to Configure Tests in Xcode

### 1. Open Project
```bash
open /Users/<user>/Dev/nitnab/NitNab/NitNab.xcodeproj
```

### 2. Create Test Targets (if they don't exist)

**Create Unit Test Target**:
1. File → New → Target
2. Select "Unit Testing Bundle"
3. Name: `NitNabTests`
4. Click Finish

**Create UI Test Target**:
1. File → New → Target
2. Select "UI Testing Bundle"
3. Name: `NitNabUITests`
4. Click Finish

### 3. Add Test Files to Targets

**For each test file**:
1. Select the file in Project Navigator
2. Open File Inspector (⌥⌘1)
3. Under "Target Membership", check the appropriate test target:
   - NitNabTests for unit tests
   - NitNabUITests for UI tests

**Or drag and drop**:
1. In Project Navigator, expand test target
2. Right-click on test target → Add Files
3. Select all test files from the appropriate directory

### 4. Configure Test Scheme

1. Product → Scheme → Edit Scheme (or ⌘<)
2. Select "Test" in the sidebar
3. Click "+" to add test targets
4. Add both NitNabTests and NitNabUITests
5. Click Close

### 5. Enable Code Coverage

1. Product → Scheme → Edit Scheme
2. Select "Test" in the sidebar
3. Go to "Options" tab
4. Check "Code Coverage"
5. Click Close

### 6. Run Tests

**Via Xcode**:
- Press ⌘U to run all tests
- Or Product → Test

**Via Command Line**:
```bash
cd /Users/<user>/Dev/nitnab/NitNab
xcodebuild test -scheme NitNab -destination 'platform=macOS'
```

## Expected Results

After configuration, you should see:
- 85+ tests run
- Most tests should pass (some may need real audio files)
- Code coverage report available

## Known Test Limitations

Some tests may need adjustment:
- **AIService tests**: Require macOS 26.0+ and Apple Intelligence
- **AudioFileManager tests**: Some need real audio files (currently use mocks)
- **UI tests**: May need accessibility identifiers added to UI elements

## Troubleshooting

**Tests not appearing**:
- Ensure files are added to correct target membership
- Clean build folder (⌘⇧K)
- Rebuild project

**Tests failing**:
- Check console for specific errors
- Some tests may be skipped on incompatible systems
- Real audio files may be needed for full coverage

**Scheme not working**:
- Ensure test action is enabled in scheme
- Check that test targets are added to the scheme

---

**Status**: Test files created and documented. Manual Xcode configuration required.
