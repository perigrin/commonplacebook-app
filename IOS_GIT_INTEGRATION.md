# iOS Git Integration with Working Copy

## Overview

Phase 5 Git integration is currently implemented for **macOS only**. iOS support will be added in a future phase using Working Copy app for git operations.

## Current Implementation (macOS)

### Components Implemented

1. **SSHKeyService** (`Commonplace Book/Core/Services/SSHKeyService.swift`)
   - Generates Ed25519 SSH key pairs using `ssh-keygen`
   - Stores private keys securely in macOS keychain
   - Provides public keys for adding to git hosts
   - macOS only (uses `Process` to shell out to `ssh-keygen`)

2. **GitService** (`Commonplace Book/Core/Services/GitService.swift`)
   - Wraps git commands using `Process`
   - Supports: init, clone, commit, push, pull, fetch, status, log
   - SSH authentication using keys from SSHKeyService
   - macOS only (uses `/usr/bin/git`)

3. **GitSyncService** (`Commonplace Book/Core/Services/GitSyncService.swift`)
   - Auto-commits notes after create/update/delete operations
   - Opportunistic background push (low priority)
   - Periodic pull (configurable interval)
   - Conflict detection and reporting
   - macOS only (depends on GitService)

4. **FileSystemNoteRepository Integration**
   - Optional GitSyncService dependency
   - Triggers git commits after note operations
   - Backwards compatible (works without git sync)

5. **UI Components**
   - SettingsView git section (macOS conditional compilation)
   - GitSetupView wizard for SSH key generation and configuration
   - Public key display and copy functionality

### Testing

Comprehensive test suites included:
- `SSHKeyServiceTests.swift` - SSH key generation and storage
- `GitServiceTests.swift` - Git operations
- `GitSyncServiceTests.swift` - Auto-commit and sync

## Future iOS Implementation

### Approach: Working Copy Integration

**Working Copy** is a premium git client for iOS with URL scheme support and x-callback-url for automation. It's the recommended approach for iOS git integration because:

1. **Mature and Reliable**: Battle-tested git implementation on iOS
2. **SSH Support**: Handles SSH keys and authentication
3. **URL Scheme API**: Can be triggered from other apps
4. **x-callback-url**: Provides success/failure callbacks
5. **User Has License**: Confirmed available for use

### Architecture for iOS

```
┌─────────────────────────────────────┐
│   Commonplace Book App (iOS)       │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  FileSystemNoteRepository    │  │
│  │                              │  │
│  │  ┌────────────────────────┐  │  │
│  │  │  GitSyncService (iOS)  │  │  │
│  │  │                        │  │  │
│  │  │  - Auto-commit queue   │  │  │
│  │  │  - Batch operations    │  │  │
│  │  │  - URL scheme builder  │  │  │
│  │  └────────────────────────┘  │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
                  │
                  │ URL Scheme
                  ▼
┌─────────────────────────────────────┐
│       Working Copy App              │
│                                     │
│  - SSH authentication               │
│  - Git operations (commit/push)     │
│  - Conflict resolution UI           │
│  - Callbacks via x-callback-url     │
└─────────────────────────────────────┘
```

### Implementation Plan

#### Phase 5B: iOS Git Integration

**1. Create WorkingCopyService (iOS only)**

```swift
// ABOUTME: Service for git operations via Working Copy URL schemes
// ABOUTME: Implements auto-commit and sync using x-callback-url protocol

#if os(iOS)
actor WorkingCopyService {
    /// Commit changes via Working Copy
    func commit(repositoryName: String, message: String) async throws

    /// Push to remote via Working Copy
    func push(repositoryName: String) async throws

    /// Pull from remote via Working Copy
    func pull(repositoryName: String) async throws

    /// Check if Working Copy is installed
    func isWorkingCopyInstalled() -> Bool

    /// Open Working Copy to repository
    func openRepository(repositoryName: String)
}
#endif
```

**2. Update GitSyncService for iOS**

- Add conditional compilation for iOS
- Use WorkingCopyService instead of GitService on iOS
- Batch commits to reduce app switching
- Queue commits and flush periodically

**3. Working Copy URL Schemes**

Working Copy supports these operations via URL schemes:

```
// Commit
working-copy://x-callback-url/commit/
    ?repo=my-notes
    &message=Update%20notes
    &x-success=commonplacebook://sync-success
    &x-error=commonplacebook://sync-error

// Push
working-copy://x-callback-url/push/
    ?repo=my-notes
    &x-success=commonplacebook://sync-success

// Pull
working-copy://x-callback-url/pull/
    ?repo=my-notes
    &x-success=commonplacebook://sync-success
```

**4. Setup Flow for iOS**

1. User taps "Git Sync" in Settings
2. App checks if Working Copy is installed
3. If not installed, show App Store link
4. If installed, guide user to:
   - Clone/create repository in Working Copy
   - Configure repository name in app
   - Enable auto-sync

**5. User Experience**

- **Silent Sync**: Most operations happen in background
- **Batch Commits**: Multiple note changes batched into single commit
- **Smart Timing**: Commits triggered when:
  - App backgrounded
  - After 5 minutes of changes
  - User manually triggers sync
- **Minimal App Switching**: Working Copy opens briefly then returns

**6. Conflict Resolution**

- Working Copy handles conflicts with its built-in UI
- App detects conflict callbacks
- Shows user notification to open Working Copy
- User resolves in Working Copy
- App continues after resolution

### API Reference: Working Copy URLs

Full documentation: https://workingcopyapp.com/url-schemes.html

Key operations needed:
- `commit` - Create commits
- `push` - Push to remote
- `pull` - Pull from remote
- `status` - Check repository status
- `read` - Read file contents (for sync verification)

### Benefits of This Approach

1. **No Swift Git Library Needed**: Avoids unmaintained libraries
2. **SSH Handled by Working Copy**: No iOS SSH key management needed
3. **Professional Git UI**: Users can manually resolve complex situations
4. **Proven Reliability**: Working Copy is production-ready
5. **User Control**: Users can see and manage their git repo

### Limitations

1. **Requires Working Copy**: Users must install additional app
2. **App Switching**: Brief app switches for operations
3. **URL Scheme Complexity**: More complex than direct git calls
4. **Licensing**: Working Copy Pro required for push operations

### Alternative: Manual Git via Files App

For users without Working Copy:

1. App writes notes to folder in Files app
2. User manages git via any iOS git client
3. App watches folder for changes
4. Read-only sync from user's perspective

This provides a fallback option for users who prefer other git clients.

## Migration Path

### Current State
- macOS: Full git integration with SSH keys
- iOS: File system only, no git sync

### Phase 5B (Future)
- macOS: No changes
- iOS: Working Copy integration
- Both: Shared note format ensures compatibility

### Testing Strategy for iOS

1. **Unit Tests**: Mock Working Copy URL responses
2. **Integration Tests**: Test with actual Working Copy app
3. **Manual Testing**: Real-world workflows
4. **Beta Testing**: TestFlight with Working Copy users

## Configuration

### macOS Git Config (Current)
```swift
struct GitSyncConfiguration {
    var enabled: Bool
    var autoCommit: Bool
    var autoPush: Bool
    var pullInterval: TimeInterval
    var userName: String?
    var userEmail: String?
    var remoteURL: String?
}
```

### iOS Working Copy Config (Future)
```swift
#if os(iOS)
struct WorkingCopyConfiguration {
    var enabled: Bool
    var repositoryName: String
    var batchCommits: Bool
    var commitInterval: TimeInterval  // Batch window
    var autoSync: Bool
}
#endif
```

## Conclusion

This phased approach allows us to:
1. ✅ Ship macOS git integration now
2. 🔄 Add iOS support later without breaking changes
3. 🎯 Use best-in-class tools for each platform
4. 🔒 Maintain data compatibility across platforms

The Working Copy approach leverages existing, proven iOS git infrastructure rather than attempting to port unmaintained Swift git libraries or implement git operations from scratch on iOS.
