# iOS URL Scheme Configuration for Working Copy Integration

## Overview

The iOS git integration requires configuring a custom URL scheme to receive callbacks from Working Copy. This document explains how to add the necessary configuration in Xcode.

## Required URL Scheme

The app needs to register the `commonplacebook://` URL scheme to handle callbacks from Working Copy.

## Xcode Configuration Steps

### 1. Open the Project in Xcode

1. Open `Commonplace Book.xcodeproj` in Xcode
2. Select the project in the navigator (blue icon at the top)
3. Select the "Commonplace Book" target under TARGETS

### 2. Add URL Types

1. Go to the "Info" tab
2. Scroll down to "URL Types" section
3. Click the "+" button to add a new URL type
4. Configure the URL type as follows:

   **URL Schemes:**
   - Identifier: `com.commonplacebook.url-scheme`
   - URL Schemes: `commonplacebook`
   - Role: `Editor`

### 3. Verify Configuration

The configuration should result in the following entry in the Info.plist (you can verify in the "Info" tab):

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.commonplacebook.url-scheme</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>commonplacebook</string>
        </array>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
    </dict>
</array>
```

## Testing the URL Scheme

### Test from Safari (iOS Device/Simulator)

1. Build and run the app on a device or simulator
2. Open Safari and enter: `commonplacebook://test`
3. Safari should prompt to open Commonplace Book
4. The app should open and log the URL in the console

### Test with Working Copy

1. Install Working Copy on the device
2. Set up a repository in Working Copy
3. Configure git sync in Commonplace Book settings
4. Make a change to a note
5. The app should open Working Copy to commit the change
6. Working Copy should callback to `commonplacebook://git-success`

## Callback URLs

The app responds to these callback URLs from Working Copy:

- `commonplacebook://git-success` - Git operation succeeded
- `commonplacebook://git-error` - Git operation failed

Query parameters may contain additional information about the operation result.

## Troubleshooting

### URL scheme not working

1. Clean build folder (Product → Clean Build Folder)
2. Delete app from device/simulator
3. Rebuild and reinstall
4. Check console logs for URL handling messages

### Working Copy not opening

1. Verify Working Copy is installed
2. Check repository name matches exactly
3. Test Working Copy directly with a simple URL:
   `working-copy://x-callback-url/status?repo=test-repo`

### Callbacks not received

1. Check URL scheme is registered correctly in Info tab
2. Verify `onOpenURL` handler is present in app code
3. Check console for "Received URL" log messages
4. Ensure Working Copy is using correct callback URLs

## Implementation Details

### App Code

The URL handling is implemented in `Commonplace_BookApp.swift`:

```swift
#if os(iOS)
.onOpenURL { url in
    handleIncomingURL(url)
}
#endif
```

The `handleIncomingURL` method delegates to `WorkingCopyService.handleIncomingURL()` which processes Working Copy callbacks.

### Working Copy Service

`WorkingCopyService.swift` generates callback URLs for all git operations:

- Commit: includes `x-success` and `x-error` callbacks
- Push: includes callbacks
- Pull: includes callbacks
- Clone: includes callbacks

All callbacks use the `commonplacebook://` scheme.

## Security Considerations

1. **URL Validation**: The app validates that incoming URLs are from expected sources
2. **Timeout**: URL callbacks have a 30-second timeout to prevent hanging
3. **Error Handling**: All callback errors are logged and reported to the user

## Next Steps

After configuring the URL scheme:

1. Build the app for iOS
2. Run on device or simulator
3. Test URL handling with Safari
4. Set up Working Copy integration
5. Test end-to-end git sync workflow

## References

- [Working Copy URL Schemes](https://workingcopyapp.com/url-schemes.html)
- [Apple URL Scheme Documentation](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [SwiftUI onOpenURL Modifier](https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:))
