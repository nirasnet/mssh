import Foundation
import SwiftTerm
import Citadel
import NIO
import NIOSSH

/// Bridges SwiftTerm's TerminalView with Citadel's SSH PTY channel.
/// Handles keepalive, error recovery, and clean disconnect on iOS.
@MainActor
final class SSHTerminalBridge: NSObject, ObservableObject {
    weak var terminalView: TerminalView?

    @Published var isConnected = false
    @Published var statusMessage = "Disconnected"

    /// Called on MainActor whenever isConnected or statusMessage changes.
    var onStateChange: ((_ connected: Bool, _ status: String) -> Void)?

    private var connectionTask: Task<Void, Never>?
    private var writer: TTYStdinWriter?
    private var isDisconnecting = false

    /// Serialized write queue — all SSH writes are funnelled through this stream
    /// so that only one `outbound.write` is in-flight at a time.
    ///
    /// Background: Thai (and other multi-byte UTF-8) IME input can produce several
    /// rapid `send` callbacks in quick succession.  Each used to spawn a new
    /// `Task { @MainActor }` that called `await writer.write` concurrently.
    /// NIO's channel pipeline is not designed for concurrent callers and would
    /// deadlock/stall the SSH channel, causing the app to hang indefinitely.
    /// Routing every write through an AsyncStream ensures strict serialisation.
    private var writeStreamContinuation: AsyncStream<[UInt8]>.Continuation?

    private func updateState(connected: Bool, status: String) {
        isConnected = connected
        statusMessage = status
        onStateChange?(connected, status)
    }

    func connect(client: SSHClient, cols: Int, rows: Int) {
        // Cancel any existing connection first
        if connectionTask != nil {
            disconnect()
        }

        isDisconnecting = false
        updateState(connected: false, status: "Opening terminal...")

        connectionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.runPTYSession(client: client, cols: cols, rows: rows)
            } catch is CancellationError {
                // Normal disconnect — don't show error
            } catch let error as NIOSSHError {
                let msg = self.friendlySSHError(error)
                self.updateState(connected: false, status: msg)
            } catch {
                if !self.isDisconnecting {
                    self.updateState(connected: false, status: "Error: \(error.localizedDescription)")
                }
            }
            self.writer = nil
            if !self.isDisconnecting {
                self.updateState(connected: false, status: "Disconnected")
            }
        }
    }

    func disconnect() {
        isDisconnecting = true
        connectionTask?.cancel()
        connectionTask = nil
        writer = nil
        // Signal the write loop to stop
        writeStreamContinuation?.finish()
        writeStreamContinuation = nil
        updateState(connected: false, status: "Disconnected")
    }

    /// Queue bytes for delivery to the SSH channel.
    ///
    /// Bytes are yielded into the serialised AsyncStream consumed by the write
    /// task inside `runPTYSession`.  This replaces the old pattern of spawning a
    /// fresh `Task { await writer.write(...) }` per keystroke, which allowed
    /// concurrent writes and caused hangs with multi-byte input (e.g. Thai UTF-8).
    nonisolated func sendToSSH(data: ArraySlice<UInt8>) {
        let bytes = Array(data)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.writeStreamContinuation?.yield(bytes)
        }
    }

    nonisolated func resizeTerminal(cols: Int, rows: Int) {
        guard cols > 0, rows > 0 else { return }
        Task { @MainActor [weak self] in
            guard let self, let writer = self.writer else { return }
            do {
                try await writer.changeSize(cols: cols, rows: rows, pixelWidth: 0, pixelHeight: 0)
            } catch {
                // Resize failure is non-fatal, just log
                print("[mSSH] Resize failed: \(error)")
            }
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

        // Create a serialised write stream for this PTY session.
        // The producer side (continuation) is stored on self so that sendToSSH()
        // can yield bytes from the main actor.  The consumer side (writeStream)
        // is drained by the dedicated writerTask below — one write at a time.
        let (writeStream, writeContinuation) = AsyncStream<[UInt8]>.makeStream()
        self.writeStreamContinuation = writeContinuation

        defer {
            // Always tidy up the continuation when this session exits, regardless
            // of how it exits (cancellation, error, normal completion).
            writeContinuation.finish()
            if self.writeStreamContinuation != nil {
                self.writeStreamContinuation = nil
            }
        }

        try await client.withPTY(ptyRequest) { [weak self] inbound, outbound in
            guard let self else { return }

            await MainActor.run {
                self.writer = outbound
                self.updateState(connected: true, status: "Connected")
            }

            // Writer task: drains the write stream ONE item at a time, guaranteeing
            // that each `outbound.write` completes before the next one starts.
            // This is the key fix for the Thai-character hang: no concurrent writes.
            let writerTask = Task {
                for await bytes in writeStream {
                    guard !Task.isCancelled else { break }
                    do {
                        let buffer = ByteBuffer(bytes: bytes)
                        try await outbound.write(buffer)
                    } catch {
                        // Write failure means the channel is dead; report and bail.
                        await MainActor.run { [weak self] in
                            guard let self, !self.isDisconnecting else { return }
                            self.updateState(connected: false, status: "Connection lost")
                        }
                        break
                    }
                }
            }

            // Read SSH output and feed to terminal — this loop keeps the PTY alive
            do {
                for try await chunk in inbound {
                    // Check for cancellation periodically
                    try Task.checkCancellation()

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
            } catch is CancellationError {
                writerTask.cancel()
                throw CancellationError()
            } catch {
                writerTask.cancel()
                await MainActor.run {
                    if !self.isDisconnecting {
                        self.updateState(connected: false, status: "Connection lost: \(error.localizedDescription)")
                    }
                }
            }

            writerTask.cancel()
        }
    }

    /// Convert NIOSSHError to user-friendly messages
    private func friendlySSHError(_ error: NIOSSHError) -> String {
        let desc = String(describing: error)
        if desc.contains("algorithm") || desc.contains("negotiation") {
            return "Algorithm negotiation failed. This server may use unsupported encryption."
        }
        if desc.contains("auth") {
            return "Authentication failed. Check your password or SSH key."
        }
        if desc.contains("channel") || desc.contains("open") {
            return "Failed to open terminal channel."
        }
        if desc.contains("banner") || desc.contains("protocol") {
            return "SSH protocol error. The server may not be running SSH."
        }
        return "SSH error: \(error.localizedDescription)"
    }
}
