# iOS Git Integration with Working Copy

## Overview

Phase 5 Git integration is now implemented for both **macOS and iOS**. iOS uses the Working Copy app for git operations via x-callback-url protocol.

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

## Implementation Status

### Phase 5 - macOS Git Integration ✅ COMPLETE
- SSHKeyService for key generation and keychain storage
- GitService for git operations (init, clone, commit, push, pull)
- GitSyncService for automatic synchronization
- GitSetupView wizard
- Full test coverage (46 tests)

### Phase 5b - iOS Git Integration ✅ COMPLETE

**Services Implemented:**

1. **WorkingCopyService** (`Commonplace Book/Core/Services/WorkingCopyService.swift`)
   - x-callback-url protocol support
   - URL generation for commit, push, pull, clone, status
   - Callback handling with async/await
   - Working Copy detection via canOpenURL
   - Timeout and error handling

2. **GitSyncServiceiOS** (`Commonplace Book/Core/Services/GitSyncServiceiOS.swift`)
   - Matches macOS GitSyncService API exactly
   - Auto-commit with batching (5-second window)
   - Background push (low priority)
   - Periodic pull (configurable interval)
   - Event handlers for sync status
   - Uses WorkingCopyService instead of GitService

3. **FileSystemNoteRepository Updates**
   - Platform-specific git sync service support
   - iOS and macOS use identical API calls
   - Conditional compilation for service types
   - Git commits triggered on create, update, delete, restore, purge

**UI Components:**

1. **GitSetupViewiOS** (`Commonplace Book/Presentation/Views/GitSetupViewiOS.swift`)
   - 6-step wizard:
     1. Welcome
     2. Install/Detect Working Copy
     3. Configure Repository (URL, name)
     4. Clone Repository in Working Copy
     5. Test Connection
     6. Complete
   - Auto-extraction of repository name from URL
   - App Store link for Working Copy
   - Repository URL validation
   - Configuration persistence

2. **SettingsView Updates**
   - iOS git integration section
   - Platform-specific messaging
   - Sheet presentation for GitSetupViewiOS

**URL Scheme Integration:**

1. **App URL Handling** (`Commonplace Book/App/Commonplace_BookApp.swift`)
   - `onOpenURL` handler for iOS
   - Working Copy callback processing
   - Event logging for debugging

2. **URL Scheme Configuration** (`IOS_URL_SCHEME_SETUP.md`)
   - `commonplacebook://` URL scheme
   - Xcode setup instructions
   - Testing procedures
   - Troubleshooting guide

**Test Coverage:**

1. **WorkingCopyServiceTests** - 8 tests
   - URL generation validation
   - Working Copy detection
   - Callback URL formatting

2. **GitSyncServiceiOSTests** - 10 tests
   - Configuration management
   - Auto-commit behavior
   - Push/pull operations
   - Timer management
   - Repository setup

3. **GitSetupViewiOSTests** - 5 tests
   - Wizard step navigation
   - Repository URL validation
   - Repository name extraction
   - Step progression logic

4. **GitIntegrationiOSTests** - 9 tests
   - Note create/update/delete workflows
   - Git commit triggers
   - Configuration effects
   - Graceful degradation without Working Copy
   - Event handler integration

**Total iOS Tests: 32 tests** (exceeds requirement of 29+)

## User-Facing Setup Instructions

### For iOS Users

1. **Install Working Copy**
   - Download from App Store (free version works for cloning)
   - Working Copy Pro required for push operations

2. **Set Up Repository in Working Copy**
   - Create or clone your notes repository
   - Configure SSH keys in Working Copy settings
   - Note the repository name (used for URL scheme)

3. **Configure Commonplace Book**
   - Open Settings → Git Integration
   - Tap "Git Synchronization Setup"
   - Follow wizard to configure repository
   - Enter repository URL (SSH or HTTPS)
   - Enter repository name (must match Working Copy)
   - Test connection

4. **Enable Automatic Sync**
   - Auto-commit enabled by default
   - Background push happens after commits
   - Periodic pull checks for remote changes

### URL Scheme Configuration

**Required for Xcode Project:**

Add to Info.plist via Xcode:
```
URL Types → Add New
- Identifier: com.commonplacebook.url-scheme
- URL Schemes: commonplacebook
- Role: Editor
```

See `IOS_URL_SCHEME_SETUP.md` for detailed instructions.

## Troubleshooting

### iOS-Specific Issues

**Working Copy not opening:**
- Verify Working Copy is installed
- Check repository name matches exactly
- Test Working Copy directly with a URL scheme

**Callbacks not working:**
- Verify URL scheme is registered in Xcode
- Check console logs for "Received URL" messages
- Ensure Working Copy is using correct callback URLs

**Commits not syncing:**
- Check Working Copy permissions
- Verify repository is configured correctly
- Check Working Copy status manually
- Review event logs in Commonplace Book

**Performance:**
- Commits are batched over 5 seconds to reduce app switching
- Background operations use low priority
- Pull timer is configurable (default 5 minutes)

## Architecture Comparison

### macOS Architecture
```
FileSystemNoteRepository
    └── GitSyncService
        └── GitService (shell commands)
            └── SSHKeyService (keychain)
```

### iOS Architecture
```
FileSystemNoteRepository
    └── GitSyncServiceiOS
        └── WorkingCopyService (x-callback-url)
            └── Working Copy App
```

Both platforms:
- Share GitSyncConfiguration struct
- Use identical GitSyncEvent enum
- Expose same public API
- Support same git operations

## Conclusion

Phase 5b successfully implements iOS git integration:
1. ✅ macOS git integration via shell commands
2. ✅ iOS git integration via Working Copy
3. ✅ Platform-specific implementations with shared API
4. ✅ Comprehensive test coverage (78 total tests)
5. ✅ User-friendly setup wizards for both platforms
6. ✅ Graceful degradation without git/Working Copy
7. ✅ Full documentation and troubleshooting guides

The Working Copy approach leverages existing, proven iOS git infrastructure rather than attempting to port unmaintained Swift git libraries or implement git operations from scratch on iOS. Both platforms can sync to the same git repository, enabling true cross-platform note synchronization.
