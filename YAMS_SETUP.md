# Yams Dependency Setup

## Why Yams?

The NoteFileFormatter currently uses a custom YAML parser which has known limitations:
- Fails on valid YAML with quoted strings containing colons
- No security protections (DoS via large YAML, recursion attacks)
- Doesn't handle deeply nested structures
- Loses type information for complex values

The [Yams library](https://github.com/jpsim/Yams) is a production-ready YAML parser that solves all these issues.

## Adding Yams to the Project

### Option 1: Via Xcode (Recommended)

1. Open `Commonplace Book.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the "Commonplace Book" target
4. Go to "Package Dependencies" tab
5. Click the "+" button
6. Enter the repository URL: `https://github.com/jpsim/Yams`
7. Click "Add Package"
8. Select "Yams" product and click "Add Package"

### Option 2: Manual Package.swift (For Command-Line Builds)

If you want to build from command line with `swift build`:

```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CommonplaceBook",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CommonplaceBook",
            targets: ["CommonplaceBook"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "CommonplaceBook",
            dependencies: ["Yams"]),
        .testTarget(
            name: "CommonplaceBookTests",
            dependencies: ["CommonplaceBook"]),
    ]
)
```

## Verification

After adding Yams, the code in `NoteFileFormatter.swift` will automatically use it instead of the fallback parser. You can verify by:

1. Running the tests: All NoteFileFormatterTests should pass
2. The file should compile without warnings about unavailable Yams import
3. Complex YAML edge cases will now work correctly

## Current Status

The code has conditional compilation:
- **With Yams**: Uses production-ready Yams parser
- **Without Yams**: Falls back to simplified custom parser (with known limitations)

## Migration

Once Yams is added, no code changes are needed - the implementation automatically switches to using Yams via conditional compilation.
