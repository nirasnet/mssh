import SwiftUI
import SwiftData

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
            }
            .environment(sessionManager)
            .environment(syncService)
            .onAppear {
                if hasCompletedOnboarding && biometricEnabled && BiometricService.canUseBiometrics() {
                    isLocked = true
                }
                AutoImportService.importIfNeeded(modelContext: modelContainer.mainContext)
            }
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .defaultSize(width: 900, height: 650)
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
        let syncEnabled = defaults.bool(forKey: "cloudSyncEnabled")

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
