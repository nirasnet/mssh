# mSSH v1.0.1 — Bug Fix Report

**Date:** 2026-04-02
**Version:** 1.0.1 (build 3)
**Fixes:** 2 bugs

---

## Bug 1 — Thai language input hangs SSH terminal

### Symptoms
Switching to the Thai keyboard, typing 1–2 characters, and the app hangs indefinitely. The SSH session becomes unresponsive; no further input or output is processed.

### Root Cause
`SSHTerminalBridge.sendToSSH(data:)` was spawning a new Swift `Task { @MainActor }` for every keystroke, each of which called `await writer.write(buffer)` directly:

```swift
// OLD — broken
nonisolated func sendToSSH(data: ArraySlice<UInt8>) {
    let bytes = Array(data)
    Task { @MainActor [weak self] in
        guard let self, let writer = self.writer else { return }
        let buffer = ByteBuffer(bytes: bytes)
        try await writer.write(buffer)   // ← concurrent callers!
    }
}
```

`TTYStdinWriter.write` ultimately calls NIO's `Channel.writeAndFlush`, which is not designed for concurrent callers. With Thai IME input, iOS fires the `send` delegate callback rapidly (once per composed character, sometimes with intermediate composition events). Multiple tasks ended up suspended at the same `await writer.write` point simultaneously, putting the NIO channel pipeline into a deadlocked/stalled state from which it never recovered.

Thai characters are 3-byte UTF-8 code points (U+0E00–U+0E7F). The IME layer can also produce multiple rapid callbacks during the composition/commit cycle. ASCII input rarely triggers this race because keystrokes arrive more slowly and each write completes before the next one begins.

### Fix
`mssh/Terminal/SSHTerminalBridge.swift`

All writes are now funnelled through a single `AsyncStream<[UInt8]>` whose consumer task processes one item at a time, guaranteeing that each `outbound.write` completes before the next starts:

```swift
// NEW — serialised via AsyncStream
private var writeStreamContinuation: AsyncStream<[UInt8]>.Continuation?

nonisolated func sendToSSH(data: ArraySlice<UInt8>) {
    let bytes = Array(data)
    Task { @MainActor [weak self] in
        self?.writeStreamContinuation?.yield(bytes)   // ← enqueue, never await here
    }
}
```

Inside `runPTYSession`, a dedicated **writer task** drains the stream:

```swift
let (writeStream, writeContinuation) = AsyncStream<[UInt8]>.makeStream()
self.writeStreamContinuation = writeContinuation

let writerTask = Task {
    for await bytes in writeStream {
        guard !Task.isCancelled else { break }
        try await outbound.write(ByteBuffer(bytes: bytes))  // exactly one at a time
    }
}
```

The stream is finished (signalling the writer task to exit cleanly) in both `disconnect()` and the `defer` block at the end of `runPTYSession`.

**Effect:** Thai characters, emoji, Chinese, Japanese, Korean, and any other multi-byte IME input are now queued and sent sequentially. ASCII behaviour is unchanged.

---

## Bug 2 — White screen after force-close

### Symptoms
After force-killing the app (swipe up in the app switcher, especially after the Bug 1 hang), relaunching shows a permanently white/blank screen. The app appears to launch but never renders any UI.

### Root Cause
`msshApp.init()` created the SwiftData `ModelContainer` with a bare `try … catch { fatalError(…) }`:

```swift
// OLD — crashes on corrupt store
init() {
    do {
        modelContainer = try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Failed to create ModelContainer: \(error)")   // ← kills the process
    }
}
```

Force-killing the app can leave SwiftData's SQLite WAL (Write-Ahead Log) or SHM (shared memory) auxiliary files in an inconsistent state because the OS sends SIGKILL with no clean-shutdown opportunity. On the next launch, SwiftData fails to open the store and throws an error. `fatalError` terminates the process before any UI is drawn — the user sees only the white launch screen, then the app silently disappears. This looks like a "white screen" because the crash happens so fast.

### Fix
`mssh/App/msshApp.swift`

The `ModelContainer` creation was refactored into a four-stage recovery method `makeModelContainer(schema:)`:

1. **Normal open** — tries to open the existing persistent store as usual.
2. **WAL/SHM cleanup** — if step 1 fails, deletes the SQLite auxiliary files (`.wal`, `.shm`) from Application Support and retries. These side-files are the most common corruption point after SIGKILL.
3. **Full store deletion** — if still failing, removes all `*.store` / `default.*` files from Application Support and tries again with a fresh empty database.
4. **In-memory fallback** — absolute last resort; the app always launches with a working (empty) in-memory store rather than crashing. User data will not persist in this case, but the UI is fully functional.

```swift
private static func makeModelContainer(schema: Schema) -> ModelContainer {
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

    if let container = try? ModelContainer(for: schema, configurations: [config]) {
        return container                            // ← 99% case
    }

    // Remove WAL / SHM side-files
    // … (delete .wal / .shm files) …
    if let container = try? ModelContainer(for: schema, configurations: [config]) {
        return container
    }

    // Delete whole store and start fresh
    // … (delete .store / default.* files) …
    if let container = try? ModelContainer(for: schema, configurations: [config]) {
        return container
    }

    // In-memory fallback — app always launches
    let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try! ModelContainer(for: schema, configurations: [memConfig])
}
```

**Effect:** The app always launches and renders its UI correctly after any kind of abnormal termination, including SIGKILL during a hang.

---

## Version Changes

| Field | Before | After |
|-------|--------|-------|
| `CFBundleShortVersionString` | 1.0.0 | **1.0.1** |
| `CFBundleVersion` (build) | 2 | **3** |
| `MARKETING_VERSION` (xcodeproj) | 1.0.0 | **1.0.1** |
| `CURRENT_PROJECT_VERSION` (xcodeproj) | 2 | **3** |

---

## Files Changed

| File | Change |
|------|--------|
| `mssh/Terminal/SSHTerminalBridge.swift` | Serialised SSH writes via `AsyncStream` (Bug 1 fix) |
| `mssh/App/msshApp.swift` | Graceful SwiftData recovery instead of `fatalError` (Bug 2 fix) |
| `mssh/Info.plist` | Version → 1.0.1, Build → 3 |
| `mssh.xcodeproj/project.pbxproj` | `MARKETING_VERSION` → 1.0.1, `CURRENT_PROJECT_VERSION` → 3 |

---

## Build & Deploy

```bash
# From ~/Desktop/projects/mssh:
bash build_and_archive.sh
```

The script performs a clean Release build, archives to `/tmp/mSSH_v1.0.1.xcarchive`, exports using `build/ExportOptions.plist` (App Store Connect, Team CC24ZA67DK), and attempts upload. Alternatively, open the `.xcarchive` in Xcode Organizer and distribute from there.
