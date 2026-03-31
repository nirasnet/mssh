import SwiftUI
import SwiftTerm

/// UIViewRepresentable wrapper for SwiftTerm's TerminalView
struct TerminalViewWrapper: UIViewRepresentable {
    @ObservedObject var bridge: SSHTerminalBridge
    var theme: TerminalTheme = .default

    func makeUIView(context: Context) -> TerminalView {
        let terminal = TerminalView()
        terminal.terminalDelegate = context.coordinator
        terminal.nativeBackgroundColor = UIColor(theme.background)
        terminal.nativeForegroundColor = UIColor(theme.foreground)

        // Configure terminal font
        let fontSize: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 14 : 12
        terminal.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        // Set up the keyboard accessory for iOS
        terminal.inputAccessoryView = makeAccessoryBar(terminal: terminal, coordinator: context.coordinator)

        // Link bridge to terminal view
        bridge.terminalView = terminal

        // If already connected (e.g. returning to an existing session),
        // request focus after a brief delay to let the view hierarchy settle.
        if bridge.isConnected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                terminal.becomeFirstResponder()
            }
        }

        return terminal
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        uiView.nativeBackgroundColor = UIColor(theme.background)
        uiView.nativeForegroundColor = UIColor(theme.foreground)

        // Auto-focus the terminal when the bridge reports connected,
        // so the keyboard activates and typing works immediately.
        if bridge.isConnected && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    private func makeAccessoryBar(terminal: TerminalView, coordinator: Coordinator) -> UIView {
        let bar = TerminalAccessoryBar(terminal: terminal)
        return bar
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        let bridge: SSHTerminalBridge

        init(bridge: SSHTerminalBridge) {
            self.bridge = bridge
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            bridge.sendToSSH(data: data)
        }

        func scrolled(source: TerminalView, position: Double) {}

        func setTerminalTitle(source: TerminalView, title: String) {}

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            bridge.resizeTerminal(cols: newCols, rows: newRows)
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            if let url = URL(string: link) {
                UIApplication.shared.open(url)
            }
        }

        func clipboardCopy(source: TerminalView, content: Data) {
            if let text = String(data: content, encoding: .utf8) {
                UIPasteboard.general.string = text
            }
        }

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
