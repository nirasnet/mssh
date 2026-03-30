import Foundation
import SwiftTerm
import Citadel
import NIO

/// Bridges SwiftTerm's TerminalView with Citadel's SSH PTY channel.
/// - Receives keystrokes from TerminalView and writes to SSH stdin
/// - Reads SSH stdout and feeds to TerminalView for rendering
@MainActor
final class SSHTerminalBridge: NSObject, ObservableObject {
    weak var terminalView: TerminalView?

    @Published var isConnected = false
    @Published var statusMessage = "Disconnected"

    private var stdinContinuation: AsyncStream<Data>.Continuation?
    private var connectionTask: Task<Void, Never>?

    func connect(client: SSHClient, cols: Int, rows: Int) {
        statusMessage = "Connecting..."
        connectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.runPTYSession(client: client, cols: cols, rows: rows)
            } catch is CancellationError {
                // Normal disconnect
            } catch {
                await MainActor.run {
                    self.statusMessage = "Error: \(error.localizedDescription)"
                }
            }
            await MainActor.run {
                self.isConnected = false
                self.stdinContinuation?.finish()
                self.stdinContinuation = nil
                self.statusMessage = "Disconnected"
            }
        }
    }

    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
    }

    /// Called by TerminalViewDelegate when user types
    func sendToSSH(data: ArraySlice<UInt8>) {
        let bytes = Data(data)
        stdinContinuation?.yield(bytes)
    }

    /// Called by TerminalViewDelegate on terminal resize
    func resizeTerminal(cols: Int, rows: Int) {
        // Resize is handled via the PTY channel — we store and use it
        // Note: Citadel's executeCommandStream doesn't expose resize after creation
        // For a more complete implementation, we'd need direct channel access
    }

    private func runPTYSession(client: SSHClient, cols: Int, rows: Int) async throws {
        // Create an async stream for stdin data from the terminal
        let (stdinStream, continuation) = AsyncStream.makeStream(of: Data.self)
        await MainActor.run {
            self.stdinContinuation = continuation
            self.isConnected = true
            self.statusMessage = "Connected"
        }

        // Use Citadel's shell execution with PTY
        let streams = try await client.executeCommandStream(
            "TERM=xterm-256color exec $SHELL -l",
            inShell: true,
            mergeStreams: true
        )

        // Read stdout in background and feed to terminal
        let outputTask = Task { [weak self] in
            for try await chunk in streams {
                guard let self else { break }
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

        // Write stdin from terminal to SSH channel
        for await data in stdinStream {
            guard !Task.isCancelled else { break }
            var buffer = ByteBuffer(data: data)
            try await streams.write(buffer)
        }

        outputTask.cancel()
    }
}
