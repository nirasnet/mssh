import Foundation
import Observation

@Observable
final class SessionManager {
    var sessions: [SessionViewModel] = []
    var activeSessionID: UUID?

    var activeSession: SessionViewModel? {
        sessions.first { $0.id == activeSessionID }
    }

    func createSession(for profile: ConnectionProfile) -> SessionViewModel {
        let session = SessionViewModel(profile: profile)
        sessions.append(session)
        activeSessionID = session.id
        return session
    }

    func closeSession(_ id: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].disconnect()
            sessions.remove(at: index)
        }
        if activeSessionID == id {
            activeSessionID = sessions.last?.id
        }
    }

    func closeAllSessions() {
        for session in sessions {
            session.disconnect()
        }
        sessions.removeAll()
        activeSessionID = nil
    }
}
