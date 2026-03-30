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

    private var stdinContinuation: AsyncStream<Data>.Continuation?
    private var connectionTask: Task<Void, Never>?
    private var writer: TTYStdinWriter?

    func connect(client: SSHClient, cols: Int, rows: Int) {
        statusMessage = "Connecting..."
        connectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.runPTYSession(client: client, cols: cols, rows: rows)
            } catch is CancellationError {
                // Normal disconnect
            } catch {
                self.statusMessage = "Error: \(error.localizedDescription)"
            }
            self.isConnected = false
            self.writer = nil
            self.stdinContinuation?.finish()
            self.stdinContinuation = nil
            self.statusMessage = "Disconnected"
        }
    }

    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
    }

    nonisolated func sendToSSH(data: ArraySlice<UInt8>) {
        let bytes = Data(data)
        Task { @MainActor in
            stdinContinuation?.yield(bytes)
        }
    }

    nonisolated func resizeTerminal(cols: Int, rows: Int) {
        Task { @MainActor in
            guard let writer else { return }
            try? await writer.changeSize(cols: cols, rows: rows, pixelWidth: 0, pixelHeight: 0)
        }
    }

    private func runPTYSession(client: SSHClient, cols: Int, rows: Int) async throws {
        let (stdinStream, continuation) = AsyncStream.makeStream(of: Data.self)
        self.stdinContinuation = continuation

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
                self.isConnected = true
                self.statusMessage = "Connected"
            }

            // Read SSH output and feed to terminal
            let outputTask = Task { [weak self] in
                for try await chunk in inbound {
                    switch chunk {
                    case .stdout(let buffer):
                        let bytes = Array(buffer.readableBytesView)
                        await MainActor.run {
                            self?.terminalView?.feed(byteArray: ArraySlice(bytes))
                        }
                    case .stderr(let buffer):
                        let bytes = Array(buffer.readableBytesView)
                        await MainActor.run {
                            self?.terminalView?.feed(byteArray: ArraySlice(bytes))
                        }
                    }
                }
            }

            // Write terminal input to SSH
            for await data in stdinStream {
                guard !Task.isCancelled else { break }
                let buffer = ByteBuffer(data: data)
                try await outbound.write(buffer)
            }

            outputTask.cancel()
        }
    }
}
