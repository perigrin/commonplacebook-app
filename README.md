# iOS Project Template

A comprehensive iOS project template that establishes a standardized foundation for Swift applications. This template includes pre-configured CI/CD pipelines, testing frameworks, a robust project architecture following MVVM pattern with SwiftUI, and common utilities.

## Project Overview

This template provides:

- **Modern Architecture**: MVVM design pattern with SwiftUI
- **Robust Directory Structure**: Organized for scalability and maintainability
- **CI/CD Configuration**: GitHub Actions workflows for automated builds and TestFlight deployment
- **Testing Framework**: Comprehensive unit and UI testing setup
- **Utilities & Extensions**: Common Swift extensions and utilities
- **Documentation**: Architecture decisions and guidelines

## Getting Started

### Prerequisites

- Xcode 15.0+
- Swift 5.9+
- CocoaPods or Swift Package Manager
- A macOS device with Git installed

### Using This Template

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/ios-app-template.git your-project-name
   ```

2. Navigate to the project directory:
   ```bash
   cd your-project-name
   ```

3. Rename the project:
   ```bash
   ./rename.sh "Your App Name" com.yourcompany.yourappname
   ```

4. Install dependencies:
   ```bash
   pod install
   ```

5. Open the workspace:
   ```bash
   open "Your App Name.xcworkspace"
   ```

6. Update the following files with your specific project information:
   - `fastlane/Appfile` - Update with your App ID and team information
   - `fastlane/Fastfile` - Customize the lanes as needed
   - `.github/workflows/*.yml` - Update with your specific build settings
   - `README.md` - Replace with your project's documentation

## Directory Structure

The project follows a feature-based directory structure:

```
Project/
├── App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── AppCoordinator.swift
│
├── Core/
│   ├── Extensions/
│   ├── Protocols/
│   ├── Utilities/
│   └── Constants.swift
│
├── Data/
│   ├── Models/
│   ├── Repositories/
│   ├── Services/
│   └── CoreData/
│      ├── ModelDefinitions/
│      └── Persistence.swift
│
├── Features/
│   ├── Feature A/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   ├── Models/
│   │   └── Services/
│   │
│   └── Feature B/
│       ├── Views/
│       ├── ViewModels/
│       ├── Models/
│       └── Services/
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

### Key Components

- **App**: Contains application entry points and coordination logic
- **Core**: Shared extensions, protocols, and utilities
- **Data**: Data models, repositories, and services
- **Features**: Feature-specific components organized in MVVM pattern
- **Resources**: Assets, localization files, and other resources

## Architecture

This template follows the MVVM (Model-View-ViewModel) architecture:

- **Model**: Represents the data and business logic
- **View**: SwiftUI views that display the user interface
- **ViewModel**: Manages the state and behavior of the View, handling user input and preparing data for display

### Dependency Injection

The template uses protocol-based dependency injection to promote testability and modularity.

### Navigation

Navigation is managed through the AppCoordinator, which centralizes navigation logic and provides a clean way to handle deep links, universal links, and push notifications.

## CI/CD Workflows

### GitHub Actions

The template includes three GitHub Actions workflows:

1. **PR Validation**: Runs on pull requests to validate the build, run tests, and perform code quality checks.
2. **TestFlight Deployment**: Automatically builds and deploys to TestFlight when code is pushed to the main branch.

### Fastlane

The template includes Fastlane configuration for:

- Building the app
- Running tests
- Deploying to TestFlight
- Uploading to App Store
- Managing certificates and provisioning profiles

To use Fastlane:

```bash
# Run tests
fastlane ios tests

# Deploy to TestFlight
fastlane ios beta

# Upload to App Store
fastlane ios release
```

## Testing Framework

The template includes a comprehensive testing framework:

- **Unit Tests**: For testing isolated components
- **UI Tests**: For testing user interfaces
- **Snapshot Tests**: For testing UI appearance

## Coding Standards

The template enforces coding standards using SwiftLint. The configuration can be found in `.swiftlint.yml`.

## Adding New Features

To add a new feature:

1. Create a new directory in the Features folder with the feature name
2. Add the Views, ViewModels, Models, and Services directories
3. Implement the feature using MVVM pattern
4. Add unit tests for the new feature

## Contributing

Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file for guidelines on contributing to this template.

## License

This template is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
