# Contributing to NitNab 🤝

Thank you for considering contributing to NitNab! We welcome contributions from the community and appreciate your help in making NitNab better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by our commitment to creating a welcoming and inclusive environment. Please be respectful and constructive in all interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (audio files, settings used, etc.)
- **Describe the behavior you observed** and what you expected
- **Include screenshots** if relevant
- **Specify your macOS version** and NitNab version

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful**
- **List any similar features** in other applications

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added code that should be tested, add tests
3. Ensure your code follows the existing style
4. Write clear, descriptive commit messages
5. Update documentation as needed
6. Submit your pull request!

## Development Setup

1. **Requirements**:
   - macOS 26.0+
   - Xcode 26.0+
   - Swift 6.0+

2. **Clone and Build**:
   ```bash
   git clone https://github.com/lanec/nitnab.git
   cd nitnab
   open NitNab/NitNab.xcodeproj
   ```

3. **Code Style**:
   - Follow Swift API Design Guidelines
   - Use SwiftLint for consistency
   - Write self-documenting code with clear names
   - Add comments for complex logic

4. **Testing**:
   - Write unit tests for new features
   - Ensure all tests pass before submitting PR
   - Test with various audio formats and languages

## Project Structure

```
NitNab/
├── Models/              # Data models and business entities
├── Services/            # Business logic and API wrappers
├── ViewModels/          # MVVM view models
└── Views/               # SwiftUI views and components
```

## Commit Message Guidelines

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

Examples:
```
Add support for FLAC audio format
Fix crash when canceling transcription
Update README with installation instructions
```

## Questions?

Feel free to open an issue with the "question" label or reach out to [@lanec](https://github.com/lanec).

Thank you for contributing! 🎉
