# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Deploy

```bash
# Regenerate Xcode project (required after adding/removing files or changing project.yml)
xcodegen generate

# Build for device
xcodebuild build -project mssh.xcodeproj -scheme mssh \
  -destination 'id=<DEVICE_ID>' \
  -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=CC24ZA67DK

# Build for simulator
xcodebuild build -project mssh.xcodeproj -scheme mssh \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES

# Install on device
xcrun devicectl device install app --device <DEVICE_ID> \
  ~/Library/Developer/Xcode/DerivedData/mssh-*/Build/Products/Debug-iphoneos/mssh.app

# Launch on device
xcrun devicectl device process launch --device <DEVICE_ID> com.m4ck.mssh

# List connected devices
xcrun devicectl list devices
```

Project uses **xcodegen** (`project.yml` is the source of truth). After modifying `project.yml`, always run `xcodegen generate` before building. Do not manually edit `mssh.xcodeproj/project.pbxproj`.

SPM dependencies: **Citadel** (0.9.0+, SSH2 protocol) and **SwiftTerm** (1.13.0+, terminal emulation). Target: iOS 18.0+, Team: CC24ZA67DK.

## Architecture

Four-layer architecture with strict data flow:

```
Views (SwiftUI) → ViewModels (@Observable, @MainActor) → Services (async) → Citadel/SwiftTerm
```

### SwiftData Models

Three `@Model` classes with iCloud sync considerations:

- **ConnectionProfile**: SSH connection configs. Uses `syncID` (stable UUID) for cross-device identity and Keychain lookups — never use `persistentModelID` (unstable). Auth type stored as `authTypeRaw` string bridged to `authType` enum (SwiftData can't persist enums directly). Optional `keyID` references an SSHKey.
- **SSHKey**: Public key metadata syncs via iCloud; private key material is Keychain-only (`keychainID` points to device-local Keychain item, never synced).
- **KnownHost**: Host key fingerprints. `hostIdentifier` is `host:port` composite marked `@Attribute(.unique)`. Dual-stored in SwiftData + Keychain for redundancy.

### The SSHTerminalBridge (critical integration point)

This is the most important class. It bridges two incompatible async paradigms:

- **Citadel** (NIO event loops, `withPTY` closure, `TTYStdinWriter`)
- **SwiftTerm** (UIKit `TerminalView`, synchronous `TerminalViewDelegate`)

Data flow:
```
Keystroke → TerminalViewDelegate.send() → bridge.sendToSSH() → TTYStdinWriter.write()
SSH output → withPTY inbound loop → MainActor → TerminalView.feed()
```

The bridge is `@MainActor ObservableObject` with `@Published` properties. It uses `nonisolated` functions (`sendToSSH`, `resizeTerminal`) that re-dispatch to MainActor via `Task`.

### @Observable vs @Published bridging

SessionViewModel uses `@Observable` (Observation framework). SSHTerminalBridge uses `@Published` (ObservableObject). These don't automatically observe each other. The bridge uses an `onStateChange` closure callback to propagate `isConnected`/`statusMessage` changes to the ViewModel's own stored properties.

TerminalViewWrapper uses `@ObservedObject var bridge` to trigger `updateUIView` when bridge state changes (e.g., calling `becomeFirstResponder()` on connect).

### Host key TOFU (Trust On First Use)

Uses `CheckedContinuation` to bridge NIO's synchronous validator callback to SwiftUI alerts:
1. `TOFUHostKeyValidator` implements `NIOSSHClientServerAuthenticationDelegate` (marked `@unchecked Sendable` to cross NIO event loop boundary)
2. On unknown/changed key, it calls `promptHandler` (async closure from SessionViewModel), using `Task` to escape from NIO event loop to MainActor
3. SessionViewModel stores the continuation and sets `pendingHostKeyPrompt`
4. TerminalSessionView shows `HostKeyPromptView` overlay
5. User taps Accept/Reject → continuation resumes → validator completes

**Critical**: If disconnect happens while prompt is pending, `rejectHostKey()` must be called to avoid hanging the continuation forever.

### Session management

`SessionManager` (`@MainActor @Observable`) holds an array of `SessionViewModel` instances and an `activeSessionID`. Each `SessionViewModel` creates a single `SSHTerminalBridge` in its init. SessionManager calls `disconnect()` on sessions before removal and falls back to the last session if the active one is closed.

### Credential storage

Keychain account keys follow naming conventions: `pwd-{syncID}`, `key-{keyID}`, `hostkey-{host}:{port}`.

- **Passwords**: Keychain, keyed by `ConnectionProfile.syncID` (not persistentModelID which is unstable)
- **Private SSH keys**: Keychain only (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), never in SwiftData
- **Connection profiles**: SwiftData `@Model` with `cloudKitDatabase: .none`
- **Host keys**: Both SwiftData (KnownHost model) and Keychain

## Key Constraints

- **Two-stage SSH connect**: SSHService tries default algorithms first (to avoid Citadel `.all` buffer overflow bug #76), then retries with `.all` if algorithm negotiation fails. This gives maximum server compatibility while avoiding the known bug. 15-second timeout prevents hanging on mobile.
- **RSA keys**: Only OpenSSH format works (PKCS#1/PKCS#8 require BoringSSL which isn't accessible from app target). Convert with `ssh-keygen -p -N "" -o -f <key>`. PEMParser detects format via regex on PEM headers and handles DER/ASN.1 for PKCS#8 ed25519.
- **SwiftData saves**: Always call `try? modelContext.save()` explicitly, especially in sheets. Auto-save is unreliable when sheets dismiss immediately after insert.
- **Info.plist keys**: Must be set in `project.yml` under `info.properties`, not edited manually (xcodegen overwrites Info.plist on regenerate).
- **iCloud entitlements**: Require paid Apple Developer Program. Personal Team gets provisioning errors with CloudKit capabilities.
- **`NSFaceIDUsageDescription`**: Required in Info.plist for biometric toggle to work. Without it, `LAContext.canEvaluatePolicy` returns false.
- **SFTP is non-persistent**: SFTPService creates a fresh `withSFTP` closure per operation (no persistent connection). This simplifies cleanup on iOS.
- **Auth fallback**: If a synced key is missing on the current device, SSHService returns an empty password rather than failing outright — this allows the connection attempt to proceed and surface a better error message from the server.
