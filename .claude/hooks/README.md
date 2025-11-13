# Claude Code Hooks

This directory contains hooks that run automatically during Claude Code sessions.

## Session Start Hook

The `session-start` hook runs automatically when a new Claude Code web session begins.

### What it does

- **On Linux (Claude Code Web)**:
  - Checks for xtool (cross-platform Xcode replacement)
  - Displays installation instructions if not present
  - Verifies Swift and usbmuxd availability
  - Provides information about building iOS apps on Linux

- **On macOS**:
  - Automatically installs Xcode command-line tools if not already present
  - Verifies that Swift and xcodebuild are available

### Why this is needed

This iOS/macOS project requires build tools. The session-start hook ensures:

1. Developers are informed about build options (xtool on Linux, Xcode on macOS)
2. Xcode tools are automatically set up on macOS environments
3. Build tooling status is clearly communicated

### Building iOS Apps on Linux with xtool

[xtool](https://github.com/xtool-org/xtool) is a cross-platform Xcode replacement that allows building iOS apps on Linux and Windows.

**Prerequisites:**
- Swift 6.2 toolchain
- usbmuxd (for iOS device communication)
- Xcode.xip download from Apple Developer

**Quick Setup:**
```bash
# Install prerequisites
sudo apt-get update
sudo apt-get install -y usbmuxd libimobiledevice-utils

# Install Swift 6.2 from https://swift.org/install/linux

# Install xtool
curl -fL https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage -o xtool
chmod +x xtool
sudo mv xtool /usr/local/bin/

# Setup xtool (requires Apple ID)
xtool setup
```

**Important:** You'll need to download Xcode.xip from Apple Developer to extract the iOS SDK.

### Testing the hook

You can manually run the hook to see what it does:

```bash
./.claude/hooks/session-start
```

### Environment Support

- ✅ **macOS**: Full support with automatic Xcode installation
- ⚠️ **Linux/Web**: Limited support - displays helpful messages but cannot build iOS apps
- ❓ **Windows**: Not tested - iOS development requires macOS

### For Contributors

When working on this project:

- **On macOS**: The hook will automatically set up Xcode tools
- **On Linux/Web**: Use for code editing and review; build/test locally or via CI/CD
- **CI/CD**: Consider GitHub Actions with macOS runners for automated builds

### Related Documentation

- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/claude-code-on-the-web)
- [Xcode Command-Line Tools](https://developer.apple.com/xcode/)
