# Claude Code Hooks

This directory contains hooks that run automatically during Claude Code sessions.

## Why No Session Start Hook?

This project originally had a session-start hook to set up iOS/macOS build tools. However, it was removed because:

### Native macOS App Requirements

This is a **native macOS application** using AppKit, not a Catalyst app. Building requires:

- **Full Xcode on macOS** - Native macOS SDK (AppKit, IOKit, etc.)
- **8GB+ Xcode.xip download** - Impractical to download every session
- **macOS-specific APIs** - Cannot be built on Linux even with xtool

### Why xtool Doesn't Work Here

While [xtool](https://github.com/xtool-org/xtool) is an excellent tool for building iOS apps on Linux, this project has additional constraints:

**Project Architecture:**
```swift
// From DeviceInfo.swift
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit  // Native macOS frameworks
import IOKit
#endif
```

**Platform Support (from Package.swift):**
- iOS 17+ (can use xtool)
- macOS 14+ (requires native macOS SDK - cannot use xtool)

### Build Options

#### 1. **Local macOS Development (Recommended)**
Build and test on your Mac with Xcode installed:
```bash
# On macOS
xcodebuild -scheme "Commonplace Book" \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build test
```

#### 2. **GitHub Actions (CI/CD)**
Set up automated builds using macOS runners:
```yaml
name: Build and Test
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build iOS
        run: xcodebuild -scheme "Commonplace Book" ...
      - name: Build macOS
        run: xcodebuild -scheme "Commonplace Book" ...
```

#### 3. **xtool for iOS Only (Experimental)**
If you only need to build the iOS version on Linux:
```bash
# Note: Only builds iOS, not macOS
# Requires 8GB Xcode.xip download from Apple
xtool build --platform iOS
```

### What Works in Claude Code Web (Linux)

✅ **Code editing and review**
✅ **Git operations** (commit, push, PR creation)
✅ **Documentation updates**
✅ **Planning and architecture**
✅ **Issue management**

❌ **Building iOS apps** (requires Xcode.xip)
❌ **Building macOS apps** (requires macOS + Xcode)
❌ **Running tests** (requires build tools)

### Recommended Workflow

1. **Edit code** in Claude Code web (or locally)
2. **Build and test** on your Mac
3. **Use GitHub Actions** for automated CI/CD
4. **Keep documentation** updated for team collaboration

## Related Documentation

- [Xcode Command-Line Tools](https://developer.apple.com/xcode/)
- [xtool GitHub Repository](https://github.com/xtool-org/xtool) (iOS-only)
- [GitHub Actions with macOS](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources)
