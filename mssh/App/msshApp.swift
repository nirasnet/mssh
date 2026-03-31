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

    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([ConnectionProfile.self, SSHKey.self, KnownHost.self])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionManager)
                .environment(syncService)
                .overlay {
                    if isLocked {
                        LockScreenView {
                            withAnimation {
                                isLocked = false
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .onAppear {
                    if biometricEnabled && BiometricService.canUseBiometrics() {
                        isLocked = true
                    }
                }
        }
        .modelContainer(modelContainer)
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
}
