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
        let schema = Schema([ConnectionProfile.self, SSHKey.self, KnownHost.self])
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
        // Check user preference for iCloud sync (defaults to true)
        let cloudSyncEnabled = UserDefaults.standard.object(forKey: "cloudSyncEnabled") as? Bool ?? true
        let hasICloud = FileManager.default.ubiquityIdentityToken != nil
        let useCloud = cloudSyncEnabled && hasICloud
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: useCloud ? .automatic : .none
        )

        // 1. Normal open
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        print("[mSSH] SwiftData store failed to open — attempting WAL recovery.")

        // 2. Remove WAL / SHM side-files that can block a clean reopen
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
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

        // 3. Store is truly unreadable — delete it and start with an empty store
        print("[mSSH] WAL recovery failed — deleting corrupt store and starting fresh.")
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let storeFiles = (try? fm.contentsOfDirectory(
                at: appSupport,
                includingPropertiesForKeys: nil
            )) ?? []
            for url in storeFiles where url.pathExtension == "store"
                                     || url.lastPathComponent.hasPrefix("default") {
                try? fm.removeItem(at: url)
                print("[mSSH] Removed: \(url.lastPathComponent)")
            }
        }

        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }

        // 4. Absolute last resort: in-memory store so the UI always loads
        print("[mSSH] All recovery attempts failed — using in-memory store.")
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: [memConfig])
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
