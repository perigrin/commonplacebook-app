# Claude Code Hooks

This directory contains hooks that run automatically during Claude Code sessions.

## Session Start Hook

The `session-start` hook runs automatically when a new Claude Code web session begins.

### What it does

- **On Linux (Claude Code Web)**: Displays information about the environment limitations and suggests running builds locally on macOS
- **On macOS**: Automatically installs Xcode command-line tools if not already present
- Verifies that Swift and xcodebuild are available

### Why this is needed

This iOS/macOS project requires Xcode to build and test. The session-start hook ensures:

1. Developers are informed about environment limitations when using Claude Code on the web
2. Xcode tools are automatically set up on macOS environments
3. Build tooling is ready before attempting compilation

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
