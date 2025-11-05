# Contributing Guidelines

Thank you for your interest in contributing to the iOS Project Template! This document provides guidelines and instructions for contributing to this project.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) to foster an inclusive and respectful community.

## How to Contribute

### Reporting Issues

If you find a bug or have a suggestion for improving the template:

1. Check if the issue already exists in the [GitHub Issues](https://github.com/yourusername/ios-app-template/issues)
2. If not, open a new issue, providing:
   - A clear title and description
   - Steps to reproduce the issue (for bugs)
   - Expected behavior
   - Actual behavior
   - Screenshots if applicable
   - Your environment (Xcode version, macOS version, etc.)

### Pull Requests

We welcome pull requests! To submit a PR:

1. Fork the repository
2. Create a new branch from `main`
3. Make your changes
4. Ensure your code passes all tests and linting
5. Submit a pull request to the `main` branch

#### PR Guidelines

- Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Write clear commit messages
- Include tests for new features
- Update documentation as needed
- Keep PRs focused on a single concern

## Development Workflow

1. Clone the repository
2. Install dependencies with CocoaPods: `pod install`
3. Open the workspace in Xcode
4. Make your changes
5. Run tests: `fastlane test`
6. Run SwiftLint: `fastlane lint`

## Code Style

This project uses SwiftLint to enforce code style. The configuration can be found in `.swiftlint.yml`.

Key style guidelines:

- Use 4 spaces for indentation
- Maximum line length of 120 characters
- Follow Apple's naming conventions
- Document public APIs with documentation comments
- Prefer Swift's native types over Foundation types when possible

## Testing

All new code should be covered by tests:

- Unit tests for business logic
- UI tests for user interfaces
- Snapshot tests for UI appearance

Run tests with:

```bash
fastlane test
```

## Git Workflow

We follow a simplified Git flow:

- `main`: Contains stable code
- `develop`: Integration branch for new features
- Feature branches: Named `feature/description-of-feature`
- Bugfix branches: Named `bugfix/description-of-bugfix`

## Releasing

The release process is automated through GitHub Actions and Fastlane.

To create a release:

1. Merge changes into `main`
2. Tag the release with a semantic version number: `git tag v1.0.0`
3. Push the tag: `git push --tags`
4. GitHub Actions will automatically build and deploy to TestFlight

## Documentation

Documentation is a critical part of this template. Please ensure that:

- All public APIs are documented with documentation comments
- The README.md remains up-to-date
- Architecture decisions are documented in the ADR directory

## Questions?

If you have any questions or need help with contributing, please open an issue or reach out to the maintainers.

Thank you for your contributions!
