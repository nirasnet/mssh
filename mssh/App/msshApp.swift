import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct msshApp: App {
    @State private var sessionManager = SessionManager()
    @State private var syncService = iCloudSyncService()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @AppStorage("lockOnBackground") private var lockOnBackground = true
    @State private var isLocked = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    let modelContainer: ModelContainer

    init() {
        // Build the SwiftData container with graceful recovery so that a
        // corrupted store (e.g. after a force-kill mid-write) never causes the
        // app to crash on launch and show a permanent white screen.
        let schema = Schema([
            ConnectionProfile.self,
            SSHKey.self,
            KnownHost.self,
            Snippet.self,
            PortForward.self
        ])
        modelContainer = Self.makeModelContainer(schema: schema)

        // Force dark mode appearance globally
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if os(macOS)
                // macOS 26.3 workaround: the full ContentView triggers a
                // recursive NSHostingView constraint crash during initial
                // window layout. Use a stripped-down view until Apple ships
                // a fix. iOS/iPadOS use the full UI.
                MacContentView()
                #else
                if !hasCompletedOnboarding {
                    WelcomeView {
                        withAnimation {
                            hasCompletedOnboarding = true
                        }
                    }
                } else {
                    ContentView()
                        .overlay {
                            if isLocked {
                                LockScreenView {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        isLocked = false
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                }
                #endif
            }
            .environment(sessionManager)
            .environment(syncService)
            .onAppear {
                if hasCompletedOnboarding && biometricEnabled && BiometricService.canUseBiometrics() {
                    isLocked = true
                }
                AutoImportService.importIfNeeded(modelContext: modelContainer.mainContext)
                #if os(macOS)
                // Auto-pull connections from iCloud KVS on every Mac launch
                // so profiles created on iPhone/iPad appear here.
                let pullResult = ConnectionSyncBridge.pull(
                    modelContext: modelContainer.mainContext
                )
                if pullResult.connections > 0 || pullResult.snippets > 0 {
                    print("[mSSH] Auto-pulled \(pullResult.connections) connections + \(pullResult.snippets) snippets from iCloud KVS")
                }

                // First-launch: auto-prompt the user to import ~/.ssh keys.
                if hasCompletedOnboarding {
                    autoRunSSHFolderImport(
                        modelContext: modelContainer.mainContext
                    )
                }
                #endif
            }
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        // NOTE: .defaultSize removed — macOS 26.3 has a SwiftUI bug where
        // NSHostingView.updateAnimatedWindowSize during the first layout
        // triggers recursive _informContainerThatSubviewsNeedUpdateConstraints
        // → SIGABRT. Letting AppKit auto-size avoids the crash entirely.
        .commands {
            // App menu command: File → Sync → Import from ~/.ssh Folder
            CommandGroup(after: .newItem) {
                Divider()
                Button("Sync · Import from ~/.ssh Folder…") {
                    let result = SSHFolderImporter.promptAndImport(
                        modelContext: modelContainer.mainContext
                    )
                    presentImportResultAlert(result: result)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Sync · Refresh Now") {
                    // Refresh by re-running the silent importer (pulls any
                    // new keys added to ~/.ssh/ since last launch). CloudKit
                    // itself syncs continuously — this is a user-visible
                    // "I changed something, pull now" action.
                    if let result = SSHFolderImporter.runWithStoredBookmark(
                        modelContext: modelContainer.mainContext
                    ) {
                        presentImportResultAlert(result: result)
                    } else {
                        // No bookmark yet — fall back to prompt.
                        let result = SSHFolderImporter.promptAndImport(
                            modelContext: modelContainer.mainContext
                        )
                        presentImportResultAlert(result: result)
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
        #endif
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                if biometricEnabled && lockOnBackground && BiometricService.canUseBiometrics() {
                    isLocked = true
                }
            default:
                break
            }
        }
    }

    // MARK: - ModelContainer factory

    /// Creates the SwiftData ModelContainer, recovering automatically if the
    /// on-disk store is corrupt (which can happen after a force-kill).
    ///
    /// Recovery strategy:
    ///   1. Open the store normally — fast path, works 99 % of the time.
    ///   2. If that fails, delete the SQLite WAL / SHM side-files and retry.
    ///      These auxiliary files can be left in an inconsistent state when the
    ///      process is killed without a clean shutdown.
    ///   3. If still failing, delete the main store file and start fresh.
    ///   4. Last resort: fall back to an in-memory store so the app always
    ///      launches rather than showing a white screen / crashing.
    private static func makeModelContainer(schema: Schema) -> ModelContainer {
        // Read the user's sync preference directly from UserDefaults — @AppStorage
        // isn't available this early in app init. Default to TRUE so new users
        // get cross-device sync out of the box (matches Termius expectation).
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "cloudSyncEnabled") == nil {
            defaults.set(true, forKey: "cloudSyncEnabled")
        }

        // macOS 26.3 has a SwiftUI/AppKit crash: CloudKit change notifications
        // during the first NSHostingView layout trigger recursive
        // _informContainerThatSubviewsNeedUpdateConstraints → abort(). Force
        // local-only on Mac until Apple ships a fix. Data still reaches the
        // Mac via the ~/.ssh folder importer + iCloud Keychain for
        // passwords and opt-in private keys.
        #if os(macOS)
        let syncEnabled = false
        #else
        let syncEnabled = defaults.bool(forKey: "cloudSyncEnabled")
        #endif

        // Dual-store strategy (per architect review): when sync is enabled,
        // use a DIFFERENT store file (`default-cloud.store`) so the legacy
        // `default.store` written by build 7 (no CloudKit) can't poison
        // CloudKit's schema-hash comparison. On first enable we copy the
        // legacy rows into the new store.
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let localStoreURL = appSupport?.appendingPathComponent("default.store")
        let cloudStoreURL = appSupport?.appendingPathComponent("default-cloud.store")

        let activeStoreURL: URL? = syncEnabled ? cloudStoreURL : localStoreURL

        let config: ModelConfiguration
        if let url = activeStoreURL {
            config = ModelConfiguration(
                schema: schema,
                url: url,
                cloudKitDatabase: syncEnabled ? .automatic : .none
            )
        } else {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: syncEnabled ? .automatic : .none
            )
        }

        // On first enable, copy the old store to the new cloud-backed store
        // URL so existing profiles/snippets/etc. survive the switch.
        if syncEnabled,
           let local = localStoreURL, let cloud = cloudStoreURL,
           fm.fileExists(atPath: local.path),
           !fm.fileExists(atPath: cloud.path) {
            migrateStore(from: local, to: cloud, schema: schema)
        }

        // 1. Normal open
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        print("[mSSH] SwiftData store failed to open — attempting WAL recovery.")

        // 2. Remove WAL / SHM side-files that can block a clean reopen
        if let appSupport {
            let candidates = (try? fm.contentsOfDirectory(
                at: appSupport,
                includingPropertiesForKeys: nil
            )) ?? []
            for url in candidates where url.pathExtension == "wal" || url.pathExtension == "shm" {
                try? fm.removeItem(at: url)
                print("[mSSH] Removed store side-file: \(url.lastPathComponent)")
            }
        }

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            print("[mSSH] Store reopened successfully after WAL cleanup.")
            return container
        }

        // 3. CloudKit-specific recovery: if .automatic failed (e.g. no iCloud
        // account on device, or schema mismatch), fall back to local-only so
        // the app still launches. User can retry sync later from Settings.
        if syncEnabled {
            print("[mSSH] CloudKit store open failed — falling back to local-only for this launch.")
            let fallbackURL = localStoreURL
            let fallbackConfig: ModelConfiguration
            if let url = fallbackURL {
                fallbackConfig = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            } else {
                fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            }
            if let container = try? ModelContainer(for: schema, configurations: [fallbackConfig]) {
                return container
            }
        }

        // 4. Store is truly unreadable — delete the active one and start fresh
        print("[mSSH] Deleting corrupt store and starting fresh.")
        if let active = activeStoreURL {
            let base = active.deletingPathExtension().lastPathComponent
            if let appSupport {
                let storeFiles = (try? fm.contentsOfDirectory(
                    at: appSupport,
                    includingPropertiesForKeys: nil
                )) ?? []
                for url in storeFiles where url.lastPathComponent.hasPrefix(base) {
                    try? fm.removeItem(at: url)
                    print("[mSSH] Removed: \(url.lastPathComponent)")
                }
            }
        }

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        // 5. Absolute last resort: in-memory store so the UI always loads
        print("[mSSH] All recovery attempts failed — using in-memory store.")
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: [memConfig])
    }

    /// One-shot copy of the legacy local `default.store` into a new CloudKit-
    /// backed store. Runs only when the new store doesn't yet exist. Copies
    /// the SQLite file plus the WAL/SHM side files so the move is consistent.
    private static func migrateStore(from source: URL, to destination: URL, schema: Schema) {
        let fm = FileManager.default
        let extensions = ["", "-wal", "-shm"]
        for ext in extensions {
            let src = URL(fileURLWithPath: source.path + ext)
            let dst = URL(fileURLWithPath: destination.path + ext)
            if fm.fileExists(atPath: src.path) {
                do {
                    try fm.copyItem(at: src, to: dst)
                    print("[mSSH] Migrated store file to CloudKit-backed path: \(dst.lastPathComponent)")
                } catch {
                    print("[mSSH] Store copy failed (\(dst.lastPathComponent)): \(error.localizedDescription)")
                }
            }
        }
    }

    #if os(macOS)
    // MARK: - Mac ~/.ssh auto-import

    /// First-launch UX on macOS: if the user hasn't yet granted folder
    /// access, prompt them to pick `~/.ssh/` so their existing keys/config
    /// flow into mSSH (and sync up to iCloud). On subsequent launches we
    /// silently run through the stored bookmark to pick up new keys the
    /// user added outside the app.
    private func autoRunSSHFolderImport(modelContext: ModelContext) {
        if SSHFolderImporter.shouldAutoPrompt {
            // Defer well past the initial layout cycle — showing
            // NSOpenPanel during SwiftUI's first window sizing triggers
            // the same recursive-constraint crash on macOS 26.3.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let result = SSHFolderImporter.promptAndImport(modelContext: modelContext)
                if !result.isEmpty || !result.errors.isEmpty {
                    presentImportResultAlert(result: result)
                }
            }
            return
        }
        // Bookmark already granted — silent refresh (no alert unless there's
        // something noteworthy to report).
        if let result = SSHFolderImporter.runWithStoredBookmark(modelContext: modelContext),
           (result.keysImported > 0 || result.profilesImported > 0) {
            presentImportResultAlert(result: result)
        }
    }

    private func presentImportResultAlert(result: SSHFolderImportResult) {
        let alert = NSAlert()
        alert.messageText = "Import from ~/.ssh"
        var body = result.humanSummary
        if !result.errors.isEmpty {
            body += "\n\nSkipped files:\n" + result.errors.joined(separator: "\n")
        }
        alert.informativeText = body
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    #endif

    // MARK: - Appearance

    private func configureAppearance() {
        #if os(iOS)
        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1),
            .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1),
            .font: UIFont.monospacedSystemFont(ofSize: 32, weight: .bold)
        ]
        navAppearance.shadowColor = UIColor.white.withAlphaComponent(0.05)
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(red: 0.30, green: 0.85, blue: 0.85, alpha: 1)

        // Tab bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        #endif
    }
}
