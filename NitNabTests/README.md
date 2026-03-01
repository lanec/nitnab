# NitNab Test Suite

This directory contains the test suite for NitNab, ensuring all features work correctly and preventing regressions during development.

## Running Tests

### Via Xcode
- Press `⌘U` or use `Product > Test` from the menu
- Run specific test: Click the diamond icon next to the test method
- View results in Test Navigator (⌘6)

### Via Command Line
```bash
# Run all tests
xcodebuild test -scheme NitNab -destination 'platform=macOS'

# Run with specific destination
xcodebuild test -scheme NitNab -destination 'platform=macOS,arch=arm64'
```

## Test Structure

### Unit Tests
Tests for individual services and components in isolation:
- **DatabaseServiceTests.swift** - Database operations
- **AIServiceTests.swift** - AI/ML functionality
- **AudioFileManagerTests.swift** - Audio file handling
- **PersistenceServiceTests.swift** - File persistence
- **TranscriptionServiceTests.swift** - Speech recognition

### Integration Tests
Tests for complete workflows:
- **TranscriptionWorkflowTests.swift** - End-to-end transcription process

### UI Tests (Optional)
Located in `NitNabUITests/`:
- Critical user interaction flows
- File picker integration
- Settings navigation

## Test Helpers

**TestHelpers.swift** provides:
- Mock data creation (audio files, jobs, results)
- Temporary directory management
- Async test utilities
- Database test utilities

## Code Coverage

### View Coverage in Xcode
1. Enable code coverage: `Product > Scheme > Edit Scheme > Test > Options > Code Coverage`
2. Run tests (`⌘U`)
3. View coverage: `Product > Show Code Coverage` (⌘9, then select Coverage tab)

### Coverage Targets
- **Services**: >80% coverage
- **ViewModels**: >70% coverage
- **Models**: 100% coverage (simple data structures)

## Writing Tests

### Test Naming Convention
```swift
func test<MethodName>_<Scenario>_<ExpectedResult>() {
    // e.g., testSaveJob_WhenValidJob_SavesSuccessfully()
}
```

### Async Testing
```swift
func testAsyncOperation() async throws {
    let result = try await someAsyncFunction()
    XCTAssertNotNil(result)
}
```

### Actor Testing
```swift
func testActorOperation() async throws {
    let service = DatabaseService.shared
    let result = await service.someMethod()
    XCTAssertNotNil(result)
}
```

## Current Status

**Chunk 0**: Test Coverage for Existing Features (In Progress)

### Completed Tests
- [x] Test infrastructure setup
- [x] Test helpers and utilities
- [x] DatabaseService tests (20+ tests)
- [x] AIService tests (10+ tests)
- [x] AudioFileManager tests (15+ tests)
- [x] PersistenceService tests (12+ tests)
- [x] TranscriptionWorkflow tests (15+ tests)
- [x] UI tests (15+ tests)

### Coverage Metrics
- Total tests: 85+ test methods
- Passing tests: To be verified by running tests
- Code coverage: To be measured
- Test execution time: To be measured

Target: >80% coverage on critical paths

## Troubleshooting

### Tests Won't Run
- Ensure the test target is selected in Xcode
- Check that test files are added to the test target membership
- Clean build folder: `⌘⇧K`

### Flaky Tests
- Document flaky tests in the test method comments
- Investigate timing issues with async operations
- Consider increasing timeout values

### Permission Issues
- Some tests may require specific permissions
- Grant necessary permissions in System Settings
- Mock external dependencies when possible

## CI/CD Integration

Tests are designed to run in continuous integration environments:
```bash
# CI-friendly test command
xcodebuild test \
  -scheme NitNab \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult
```

## Best Practices

1. **Fast Tests**: Keep unit tests under 0.1s each
2. **Isolation**: Tests should not depend on each other
3. **Cleanup**: Always clean up test data in `tearDown()`
4. **Deterministic**: Tests should produce same results every time
5. **Readable**: Test code should be clear and self-documenting

## Notes

- Test database uses temporary directories (cleaned up automatically)
- Mock data fixtures provided in `TestHelpers.swift`
- AI tests may require macOS 26.0+ (use availability checks)
- UI tests are optional but recommended for critical paths

---

**Last Updated**: 2025-10-10  
**Test Framework**: XCTest  
**Minimum macOS**: 26.0
