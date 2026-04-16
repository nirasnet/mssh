# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Deploy

```bash
# Convenience: regenerate project, build for sim, then build/install/launch on first connected device
./build.sh

# Regenerate Xcode project (required after adding/removing files or changing project.yml)
xcodegen generate

# Build for device
xcodebuild build -project mssh.xcodeproj -scheme mssh \
  -destination 'id=<DEVICE_ID>' \
  -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=CC24ZA67DK

# Build for simulator (use exact installed device — `xcrun simctl list devices available` to check)
xcodebuild build -project mssh.xcodeproj -scheme mssh \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES

# Build macOS target — `-allowProvisioningUpdates` is required even with DEVELOPMENT_TEAM set
xcodebuild build -project mssh.xcodeproj -scheme mssh-mac \
  -destination 'platform=macOS' -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=CC24ZA67DK

# Install on device
xcrun devicectl device install app --device <DEVICE_ID> \
  ~/Library/Developer/Xcode/DerivedData/mssh-*/Build/Products/Debug-iphoneos/mssh.app

# Launch on device
xcrun devicectl device process launch --device <DEVICE_ID> com.m4ck.mssh

# List connected devices
xcrun devicectl list devices
```

Project uses **xcodegen** (`project.yml` is the source of truth). After modifying `project.yml`, always run `xcodegen generate` before building. Do not manually edit `mssh.xcodeproj/project.pbxproj`.

**Per-target source `excludes` matter.** Both targets share `path: mssh` but each excludes the other platform's `Info.plist` + entitlements (`mssh:` excludes `Info-macOS.plist` + `mssh-mac.entitlements`; `mssh-mac:` excludes `Info.plist` + `mssh.entitlements`). Without the excludes, the wrong-platform plist gets bundled as a resource with unsubstituted `$(EXECUTABLE_NAME)` placeholders, and `xcrun devicectl device install` fails with "The path to the provided bundle's main executable could not be determined."

**Adding a new `.swift` file requires `xcodegen generate` afterwards** — otherwise the build fails with "Cannot find 'X' in scope" even though the file exists. SourceKit/LSP errors will also stay stale until a real build runs; treat them as noise post-regen.

**No test target exists** — this codebase has no unit/UI tests configured. Verification is done via build success and on-device behavior.

SPM dependencies: **Citadel** (0.9.0+, SSH2 protocol) and **SwiftTerm** (1.13.0+, terminal emulation). Targets: `mssh` (iOS 18.0+) and `mssh-mac` (macOS 15.0+) — both share the same sources under `mssh/` but have separate entitlements files (`mssh.entitlements`, `mssh-mac.entitlements`) and Info.plists (`Info.plist`, `Info-macOS.plist`). Team: CC24ZA67DK.

## Architecture

Four-layer architecture with strict data flow:

```
Views (SwiftUI) → ViewModels (@Observable, @MainActor) → Services (async) → Citadel/SwiftTerm
```

### SwiftData Models

Five `@Model` classes — all registered in the schema in `msshApp.swift:makeModelContainer`. **Adding a new `@Model` requires adding it to that `Schema([...])` array AND running `xcodegen generate`.** All fields use safe defaults so SwiftData migrates additive changes without prompting.

- **ConnectionProfile**: SSH connection configs. Uses `syncID` (stable UUID) for cross-device identity and Keychain lookups — never use `persistentModelID` (unstable). Auth type stored as `authTypeRaw` string bridged to `authType` enum (SwiftData can't persist enums directly). Optional `keyID` references an SSHKey. Termius-style organization fields: `isFavorite` (Bool), `groupName` (String?), `colorTag` (String? — name from `ConnectionProfile.tagPalette`).
- **SSHKey**: Public key metadata syncs via iCloud; private key material is Keychain-only (`keychainID` points to device-local Keychain item, never synced).
- **KnownHost**: Host key fingerprints. `hostIdentifier` is `host:port` composite. **Do not mark `@Attribute(.unique)`** — it crashed on-device with CloudKit (fixed in build 6). De-duplication is enforced in code via `#Predicate` lookup in `HostKeyValidator`. Dual-stored in SwiftData + Keychain for redundancy.
- **Snippet**: Saved commands (label/command/useCount/lastUsedAt). Pushed to the active session via `SSHTerminalBridge.sendToSSH` from `SnippetPickerView`. The iOS keyboard accessory bar (UIView) can't present SwiftUI sheets directly, so it broadcasts `Notification.Name.openSnippetPicker` and `TerminalSessionView` listens.
- **PortForward**: Linked to a profile via `profileSyncID` (matches `ConnectionProfile.syncID`). Currently CRUD-only — `PortForwardManager.start(forward:on:)` returns `.notSupported` because Citadel 0.12 doesn't expose direct-tcpip + listener APIs cleanly. Failures surface as a non-blocking `statusMessage` so the SSH session always runs. Replace the manager body to add real forwarding without schema changes.

### AppPreferences (terminal appearance & cursor)

`mssh/Services/AppPreferences.swift` is an `@Observable` singleton centralising terminal appearance prefs. Keys are namespaced under `AppPreferences.Key.*` — the literal strings match the `@AppStorage` lookups used by SwiftUI views, so both APIs read/write the same `UserDefaults` keys coherently.

- Persists: `terminalThemeName` (lookup via `TerminalTheme.named(_:)`), `terminalFontFamily` ("System"/"Menlo"/"Courier New"/"Monaco"), `terminalFontSize` (Int, clamped 9–24), `terminalCursorStyle` ("block"/"bar"/"underline"), `terminalBlinkCursor` (Bool).
- `TerminalViewWrapper` (iOS+macOS) reads these via `@AppStorage` and applies them in `makeUIView`/`updateUIView` so live changes from Settings update the running terminal.
- **Cursor style is applied portably via the DECSCUSR escape** (`\e[N q`) through the public `terminal.feed(byteArray:)` API — SwiftTerm exposes the underlying `Terminal` as `public` on macOS but `internal` on iOS, so the escape route works on both.

### The SSHTerminalBridge (critical integration point)

This is the most important class. It bridges two incompatible async paradigms:

- **Citadel** (NIO event loops, `withPTY` closure, `TTYStdinWriter`)
- **SwiftTerm** (UIKit `TerminalView`, synchronous `TerminalViewDelegate`)

Data flow:
```
Keystroke → TerminalViewDelegate.send() → bridge.sendToSSH() → AsyncStream → writer task → TTYStdinWriter.write()
SSH output → withPTY inbound loop → MainActor → TerminalView.feed()
```

The bridge is `@MainActor ObservableObject` with `@Published` properties. It uses `nonisolated` functions (`sendToSSH`, `resizeTerminal`) that re-dispatch to MainActor via `Task`.

**Serialised write stream (do not "simplify" away)**: Outgoing keystrokes are funnelled through a single `AsyncStream<[UInt8]>` drained by one writer task inside `runPTYSession`, so only one `outbound.write` is in-flight at a time. The earlier per-keystroke `Task { await writer.write(...) }` pattern caused the SSH channel to hang under multi-byte IME input (e.g. Thai UTF-8) because NIO's pipeline isn't safe for concurrent callers. `disconnect()` must `finish()` the continuation to unblock the writer task.

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

- **Passwords**: Keychain, keyed by `ConnectionProfile.syncID` (not persistentModelID which is unstable). `resolveAuthMethod` reads device-local first, then falls back to the iCloud-synced Keychain item (`getPasswordSyncable`) so passwords saved on another device still work after profile sync.
- **Private SSH keys**: Keychain only (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), never in SwiftData
- **Connection profiles**: SwiftData `@Model` with `cloudKitDatabase: .none` (CloudKit sync currently disabled — build 7 — to fix a device crash; the iCloud entitlement is still declared in `project.yml` for future re-enable)
- **Host keys**: Both SwiftData (KnownHost model) and Keychain

## Key Constraints

- **Two-stage SSH connect**: SSHService tries default algorithms first (to avoid Citadel `.all` buffer overflow bug #76), then retries with `.all` if algorithm negotiation fails. This gives maximum server compatibility while avoiding the known bug. 15-second timeout prevents hanging on mobile.
- **RSA keys**: Only OpenSSH format works (PKCS#1/PKCS#8 require BoringSSL which isn't accessible from app target). Convert with `ssh-keygen -p -N "" -o -f <key>`. PEMParser detects format via regex on PEM headers and handles DER/ASN.1 for PKCS#8 ed25519.
- **SwiftData saves**: Always call `try? modelContext.save()` explicitly, especially in sheets. Auto-save is unreliable when sheets dismiss immediately after insert.
- **Info.plist keys**: Must be set in `project.yml` under `info.properties`, not edited manually (xcodegen overwrites Info.plist on regenerate).
- **iCloud entitlements**: Require paid Apple Developer Program. Personal Team gets provisioning errors with CloudKit capabilities.
- **`NSFaceIDUsageDescription`**: Required in Info.plist for biometric toggle to work. Without it, `LAContext.canEvaluatePolicy` returns false.
- **SFTP is non-persistent**: SFTPService creates a fresh `withSFTP` closure per operation (no persistent connection). This simplifies cleanup on iOS.
- **Auth pre-flight**: `SessionViewModel.resolveAuthMethod` is `throws`. When key auth is selected but no usable private key is on this device, it raises `AuthResolutionError.keyMissingOnDevice` and `connect()` returns *without attempting the SSH handshake* — otherwise the server's generic "Authentication failed" overwrites the actionable "import the key from the Keys tab" message. `lookupPrivateKeyForProfile` resolves `profile.keyID` against both `SSHKey.keychainID` (legacy local writes) and `SSHKey.syncID` (forward-compatible cross-device); the form picker now stores `syncID` and auto-migrates legacy `keychainID` values on save. `ConnectionRow` shows a yellow ⚠ + "No Key" badge when this profile would fail the pre-flight.
