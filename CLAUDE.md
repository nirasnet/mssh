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
  -destination 'id=<HARDWARE_UDID>' \
  -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=CC24ZA67DK

# Build for simulator (use exact installed device — `xcrun simctl list devices available` to check)
xcodebuild build -project mssh.xcodeproj -scheme mssh \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES

# Build macOS target — `-allowProvisioningUpdates` is required even with DEVELOPMENT_TEAM set
xcodebuild build -project mssh.xcodeproj -scheme mssh-mac \
  -destination 'platform=macOS' -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=CC24ZA67DK

# Install on device (uses CoreDevice UUID, NOT the hardware UDID)
xcrun devicectl device install app --device <COREDEVICE_UUID> \
  ~/Library/Developer/Xcode/DerivedData/mssh-*/Build/Products/Debug-iphoneos/mssh.app

# Launch on device
xcrun devicectl device process launch --device <COREDEVICE_UUID> com.m4ck.mssh

# List connected devices (shows CoreDevice UUIDs for devicectl)
xcrun devicectl list devices

# Archive for App Store
xcodebuild archive -project mssh.xcodeproj -scheme mssh \
  -archivePath /tmp/mssh.xcarchive -destination 'generic/platform=iOS' \
  -configuration Release -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=CC24ZA67DK
```

**Important:** `xcodebuild -destination 'id=...'` uses the **hardware UDID** (e.g. `00008150-00060D5A3CF8401C`), while `xcrun devicectl` uses the **CoreDevice UUID** (e.g. `359B813D-ECAD-5396-90FD-5B202A4C6CE8`). Get the latter from `devicectl list devices --json-output`.

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

### Platform-specific root views

- **iOS/iPadOS**: `ContentView` — TabView with Connections (iPhone List + iPad NavigationSplitView), Terminal (`SplitSessionTabView`), Keys, Settings. Full Termius-tier UI with search, favorites, groups, swipe actions.
- **macOS**: `MacContentView` — Simple NavigationSplitView with sidebar (Connections/Keys/Settings/Sync/Active Sessions). The full `ContentView` causes a recursive `NSHostingView._informContainerThatSubviewsNeedUpdateConstraints` crash on macOS 26.3 during the initial window layout animation. **Do not switch macOS back to ContentView** until Apple fixes this. The root view switch is in `msshApp.swift` via `#if os(macOS)`.

### SwiftData Models

Five `@Model` classes — all registered in the schema in `msshApp.swift:makeModelContainer`. **Adding a new `@Model` requires adding it to that `Schema([...])` array AND running `xcodegen generate`.** All fields must have inline defaults for CloudKit compatibility (container init crashes without them).

- **ConnectionProfile**: SSH connection configs. Uses `syncID` (stable UUID) for cross-device identity and Keychain lookups — never use `persistentModelID` (unstable). Auth type stored as `authTypeRaw` string bridged to `authType` enum (SwiftData can't persist enums directly). Optional `keyID` references an SSHKey (stores `syncID` for cross-device portability; legacy `keychainID` values auto-migrate on save). Organization fields: `isFavorite` (Bool), `groupName` (String?), `colorTag` (String? — name from `ConnectionProfile.tagPalette`).
- **SSHKey**: Public key metadata syncs via iCloud; private key material is Keychain-only. `syncAcrossDevices` (Bool, default false) — when true, private key bytes are stored with `kSecAttrSynchronizable:true` (iCloud Keychain, E2E encrypted) instead of `ThisDeviceOnly`. Toggle via Keys tab → long-press → "Sync Across Devices".
- **KnownHost**: Host key fingerprints. `hostIdentifier` is `host:port` composite. **Do not mark `@Attribute(.unique)`** — it crashed on-device with CloudKit (fixed in build 6). De-duplication is enforced in code via `#Predicate` lookup in `HostKeyValidator`. Dual-stored in SwiftData + Keychain for redundancy. All fields have inline defaults (required for CloudKit).
- **Snippet**: Saved commands (label/command/useCount/lastUsedAt). Pushed to the active session via `SSHTerminalBridge.sendToSSH` from `SnippetPickerView`. The iOS keyboard accessory bar (UIView) can't present SwiftUI sheets directly, so it broadcasts `Notification.Name.openSnippetPicker` and `TerminalSessionView` listens.
- **PortForward**: Linked to a profile via `profileSyncID` (matches `ConnectionProfile.syncID`). Currently CRUD-only — `PortForwardManager.start(forward:on:)` returns `.notSupported` because Citadel 0.12 doesn't expose direct-tcpip + listener APIs cleanly. Failures surface as a non-blocking `statusMessage` so the SSH session always runs. Replace the manager body to add real forwarding without schema changes.

### AppPreferences (terminal appearance & cursor)

`mssh/Services/AppPreferences.swift` is an `@Observable` singleton centralising terminal appearance prefs. Keys are namespaced under `AppPreferences.Key.*` — the literal strings match the `@AppStorage` lookups used by SwiftUI views, so both APIs read/write the same `UserDefaults` keys coherently.

- Persists: `terminalThemeName` (lookup via `TerminalTheme.named(_:)`), `terminalFontFamily` ("System"/"Menlo"/"Courier New"/"Monaco"), `terminalFontSize` (Int, clamped 9–24), `terminalCursorStyle` ("block"/"bar"/"underline"), `terminalBlinkCursor` (Bool).
- `TerminalViewWrapper` (iOS+macOS) reads these via `@AppStorage` and applies them in `makeUIView`/`updateUIView` so live changes from Settings update the running terminal.
- **Cursor style is applied portably via the DECSCUSR escape** (`\e[N q`) through the public `terminal.feed(byteArray:)` API — SwiftTerm exposes the underlying `Terminal` as `public` on macOS but `internal` on iOS, so the escape route works on both.

### Cross-device sync

Three sync channels work together:

| Channel | What syncs | Platforms | Mechanism |
|---|---|---|---|
| **SwiftData + CloudKit** | Profiles, key metadata, known hosts, snippets, port forwards | iOS ↔ iPadOS | `cloudKitDatabase: .automatic` (gated by `cloudSyncEnabled` UserDefaults flag) |
| **NSUbiquitousKeyValueStore** (ConnectionSyncBridge) | Profiles, snippets, key metadata | All (especially iPhone → Mac) | Push/Pull buttons in Settings + Mac auto-pull on launch |
| **iCloud Keychain** | Passwords (`savePasswordSyncable`), private SSH keys (when `syncAcrossDevices=true`) | All | `kSecAttrSynchronizable:true` |

**macOS CloudKit is force-disabled** (`let syncEnabled = false` in `msshApp.swift`) because macOS 26.3 has a SwiftUI/AppKit bug where CloudKit change notifications during `NSHostingView` layout cause a recursive constraint crash. The KVS bridge (`ConnectionSyncBridge`) fills the gap for Mac sync.

**iCloudSyncService** (`mssh/Services/iCloudSyncService.swift`) observes `NSPersistentCloudKitContainerEventChanged` and `.NSPersistentStoreRemoteChange`. **All property mutations are deferred via `DispatchQueue.main.async`** to avoid triggering SwiftUI re-evaluation during AppKit layout passes (macOS 26.3 crash workaround).

**SSHFolderImporter** (macOS only) scans `~/.ssh/` for private keys + `~/.ssh/config` entries. Uses `NSOpenPanel` + security-scoped bookmarks (sandboxed Mac app). Auto-prompts on first launch; silent refresh on subsequent launches. Imported keys default to `syncAcrossDevices=true` so they propagate to iPhone/iPad via iCloud Keychain.

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

**Error preservation**: The `connectionTask` catch blocks track `didSetTerminalError` so the cleanup `updateState(... "Disconnected")` at the end of `runPTYSession` doesn't overwrite a meaningful error message. Without this flag, post-handshake failures (server kicks, channel-open rejected) silently became "Disconnected" and the terminal tab showed a blank cursor.

### Terminal status banner (SplitTerminalView)

`SplitSessionTabView` (the actual Terminal tab content, NOT `TerminalSessionView`) uses `SessionBannerInfo` to decide when to show the connection banner:
- **Loading** (`Connecting...` / `Opening terminal...`): spinner + status text, no action buttons
- **Error** (any non-connected state except `""` or `Disconnected`): warning icon + Retry / Close buttons
- Shared between `singlePane` and split-pane views via `@MainActor private enum SessionBannerInfo`

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
- **Private SSH keys**: Keychain, with sync disposition controlled by `SSHKey.syncAcrossDevices`. Default: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (device-only). When sync enabled: `kSecAttrSynchronizable:true + kSecAttrAccessibleWhenUnlocked` (iCloud Keychain, E2E encrypted). `getPrivateKey` queries with `kSecAttrSynchronizableAny` so lookups find the key regardless of disposition.
- **Connection profiles**: SwiftData `@Model`. iOS/iPadOS use `cloudKitDatabase: .automatic` (CloudKit sync). macOS uses `.none` (crash workaround) + KVS bridge for sync.
- **Host keys**: Both SwiftData (KnownHost model) and Keychain

### Tip Jar (StoreKit 2)

`TipJarService` (`mssh/Services/TipJarService.swift`) is an `@Observable @MainActor` singleton that loads 3 consumable IAP products via StoreKit 2. Product IDs: `com.m4ck.mssh.tip.coffee` ($0.99), `com.m4ck.mssh.tip.lunch` ($4.99), `com.m4ck.mssh.tip.dinner` ($9.99). Products must be created as **Consumable** IAPs in App Store Connect. `TipJarView` renders the tip rows + a GitHub star link in Settings → "Support mSSH". `Configuration.storekit` provides local testing data — set it in Xcode scheme → Run → Options → StoreKit Configuration.

## Key Constraints

- **Two-stage SSH connect**: SSHService tries default algorithms first (to avoid Citadel `.all` buffer overflow bug #76), then retries with `.all` if algorithm negotiation fails. This gives maximum server compatibility while avoiding the known bug. 15-second timeout prevents hanging on mobile.
- **RSA keys**: Only OpenSSH format works (PKCS#1/PKCS#8 require BoringSSL which isn't accessible from app target). Convert with `ssh-keygen -p -N "" -o -f <key>`. PEMParser detects format via regex on PEM headers and handles DER/ASN.1 for PKCS#8 ed25519. **Citadel's RSA signer is hard-coded to legacy SHA-1 `ssh-rsa`** — modern servers (OpenSSH 9.x+, Ubuntu 24.04+) that disable `ssh-rsa` in `server-sig-algs` will reject RSA auth even with a correct key. **Use Ed25519 keys instead** for these servers, or add `PubkeyAcceptedAlgorithms +ssh-rsa` on the server (weakens security).
- **Auth pre-flight**: `SessionViewModel.resolveAuthMethod` is `throws`. When key auth is selected but no usable private key is on this device, it raises `AuthResolutionError.keyMissingOnDevice` and `connect()` returns *without attempting the SSH handshake* — otherwise the server's generic "Authentication failed" overwrites the actionable message. `SSHAuthMethod.toCitadel` also `throws` `KeyParseError.unsupportedFormat` (with the detected PEM header) instead of silently falling back to an empty password. `lookupPrivateKeyForProfile` resolves `profile.keyID` against both `SSHKey.keychainID` (legacy) and `SSHKey.syncID` (portable). `ConnectionRow` shows a yellow warning badge when the key is missing.
- **SwiftData saves**: Always call `try? modelContext.save()` explicitly, especially in sheets. Auto-save is unreliable when sheets dismiss immediately after insert.
- **Info.plist keys**: Must be set in `project.yml` under `info.properties`, not edited manually (xcodegen overwrites Info.plist on regenerate).
- **iCloud entitlements**: Require paid Apple Developer Program. Personal Team gets provisioning errors with CloudKit capabilities. KVS sync requires `com.apple.developer.ubiquity-kvstore-identifier` entitlement (in both targets).
- **`NSFaceIDUsageDescription`**: Required in Info.plist for biometric toggle to work. Without it, `LAContext.canEvaluatePolicy` returns false.
- **SFTP is non-persistent**: SFTPService creates a fresh `withSFTP` closure per operation (no persistent connection). This simplifies cleanup on iOS.
- **macOS 26.3 SwiftUI crash**: The full `ContentView` (TabView + NavigationSplitView + .searchable + complex sectioned List) triggers a recursive `NSHostingView.updateAnimatedWindowSize` → `_informContainerThatSubviewsNeedUpdateConstraints` → SIGABRT on macOS 26.3. No targeted fix resolved it (disabling CloudKit, removing `.defaultSize`, deferring `@Observable` mutations). The workaround is `MacContentView` — a simple sidebar NavigationSplitView. Additionally, `iCloudSyncService` defers all `@Observable` property mutations via `DispatchQueue.main.async` to avoid triggering SwiftUI re-evaluation during AppKit layout passes.
- **Connection test**: Uses `Network.framework` `NWConnection` for real TCP reachability + reads up to 64 bytes of the SSH banner. The old `URLSession.bytes` HTTP approach was the wrong protocol and always reported SSH servers as unreachable.
