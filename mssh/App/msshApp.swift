import SwiftUI
import SwiftData

@main
struct msshApp: App {
    @State private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionManager)
        }
        .modelContainer(for: [ConnectionProfile.self, SSHKey.self])
    }
}
