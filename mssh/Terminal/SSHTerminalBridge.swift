import Foundation
import SwiftTerm
import Citadel
import NIO
import NIOSSH

/// Bridges SwiftTerm's TerminalView with Citadel's SSH PTY channel.
@MainActor
final class SSHTerminalBridge: NSObject, ObservableObject {
    weak var terminalView: TerminalView?

    @Published var isConnected = false
    @Published var statusMessage = "Disconnected"

    /// Called on MainActor whenever isConnected or statusMessage changes.
    var onStateChange: ((_ connected: Bool, _ status: String) -> Void)?

    private var connectionTask: Task<Void, Never>?
    private var writer: TTYStdinWriter?

    private func updateState(connected: Bool, status: String) {
        isConnected = connected
        statusMessage = status
        onStateChange?(connected, status)
    }

    func connect(client: SSHClient, cols: Int, rows: Int) {
        updateState(connected: false, status: "Connecting...")
        connectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.runPTYSession(client: client, cols: cols, rows: rows)
            } catch is CancellationError {
                // Normal disconnect
            } catch {
                self.updateState(connected: false, status: "Error: \(error.localizedDescription)")
            }
            self.writer = nil
            self.updateState(connected: false, status: "Disconnected")
        }
    }

    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
    }

    nonisolated func sendToSSH(data: ArraySlice<UInt8>) {
        let bytes = Array(data)
        Task { @MainActor [weak self] in
            guard let self, let writer = self.writer else { return }
            let buffer = ByteBuffer(bytes: bytes)
            try? await writer.write(buffer)
        }
    }

    nonisolated func resizeTerminal(cols: Int, rows: Int) {
        Task { @MainActor [weak self] in
            guard let self, let writer = self.writer else { return }
            try? await writer.changeSize(cols: cols, rows: rows, pixelWidth: 0, pixelHeight: 0)
        }
    }

    private func runPTYSession(client: SSHClient, cols: Int, rows: Int) async throws {
        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: cols,
            terminalRowHeight: rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )

        try await client.withPTY(ptyRequest) { [weak self] inbound, outbound in
            guard let self else { return }

            await MainActor.run {
                self.writer = outbound
                self.updateState(connected: true, status: "Connected")
            }

            // Read SSH output and feed to terminal — this keeps the PTY alive
            for try await chunk in inbound {
                switch chunk {
                case .stdout(let buffer):
                    let bytes = Array(buffer.readableBytesView)
                    await MainActor.run {
                        self.terminalView?.feed(byteArray: ArraySlice(bytes))
                    }
                case .stderr(let buffer):
                    let bytes = Array(buffer.readableBytesView)
                    await MainActor.run {
                        self.terminalView?.feed(byteArray: ArraySlice(bytes))
                    }
                }
            }
        }
    }
}
