import SwiftUI
import SwiftTerm

#if os(iOS)
/// UIViewRepresentable wrapper for SwiftTerm's TerminalView (iOS)
struct TerminalViewWrapper: UIViewRepresentable {
    @ObservedObject var bridge: SSHTerminalBridge
    @AppStorage("terminalThemeName") private var themeName = "Default"
    @AppStorage("terminalFontSize") private var fontSize = 13.0

    private var theme: TerminalTheme {
        TerminalTheme.allThemes.first { $0.name == themeName } ?? .default
    }

    func makeUIView(context: Context) -> TerminalView {
        let terminal = TerminalView()
        terminal.terminalDelegate = context.coordinator
        terminal.nativeBackgroundColor = UIColor(theme.background)
        terminal.nativeForegroundColor = UIColor(theme.foreground)

        let effectiveFontSize: CGFloat = fontSize > 0 ? CGFloat(fontSize) : (UIDevice.current.userInterfaceIdiom == .pad ? 14 : 12)
        terminal.font = UIFont.monospacedSystemFont(ofSize: effectiveFontSize, weight: .regular)

        terminal.inputAccessoryView = TerminalAccessoryBar(terminal: terminal)
        bridge.terminalView = terminal

        if bridge.isConnected {
            Self.focusWithRetry(terminal)
        }

        return terminal
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        uiView.nativeBackgroundColor = UIColor(theme.background)
        uiView.nativeForegroundColor = UIColor(theme.foreground)

        let effectiveFontSize = CGFloat(fontSize)
        let currentSize = uiView.font.pointSize
        if abs(currentSize - effectiveFontSize) > 0.5 {
            uiView.font = UIFont.monospacedSystemFont(ofSize: effectiveFontSize, weight: .regular)
        }

        if bridge.isConnected && !uiView.isFirstResponder {
            Self.focusWithRetry(uiView)
        }
    }

    private static func focusWithRetry(_ view: TerminalView, attempt: Int = 0) {
        let maxAttempts = 4
        let delays: [TimeInterval] = [0.1, 0.3, 0.6, 1.0]
        let delay = attempt < delays.count ? delays[attempt] : 1.0

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard view.window != nil else { return }
            if !view.isFirstResponder {
                let success = view.becomeFirstResponder()
                if !success && attempt + 1 < maxAttempts {
                    focusWithRetry(view, attempt: attempt + 1)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
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

#elseif os(macOS)
/// NSViewRepresentable wrapper for SwiftTerm's TerminalView (macOS)
struct TerminalViewWrapper: NSViewRepresentable {
    @ObservedObject var bridge: SSHTerminalBridge
    @AppStorage("terminalThemeName") private var themeName = "Default"
    @AppStorage("terminalFontSize") private var fontSize = 14.0

    private var theme: TerminalTheme {
        TerminalTheme.allThemes.first { $0.name == themeName } ?? .default
    }

    func makeNSView(context: Context) -> TerminalView {
        let terminal = TerminalView()
        terminal.terminalDelegate = context.coordinator
        terminal.nativeBackgroundColor = NSColor(theme.background)
        terminal.nativeForegroundColor = NSColor(theme.foreground)

        let effectiveFontSize: CGFloat = fontSize > 0 ? CGFloat(fontSize) : 14
        terminal.font = NSFont.monospacedSystemFont(ofSize: effectiveFontSize, weight: .regular)

        bridge.terminalView = terminal

        if bridge.isConnected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                terminal.window?.makeFirstResponder(terminal)
            }
        }

        return terminal
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {
        nsView.nativeBackgroundColor = NSColor(theme.background)
        nsView.nativeForegroundColor = NSColor(theme.foreground)

        let effectiveFontSize = CGFloat(fontSize)
        let currentSize = nsView.font.pointSize
        if abs(currentSize - effectiveFontSize) > 0.5 {
            nsView.font = NSFont.monospacedSystemFont(ofSize: effectiveFontSize, weight: .regular)
        }

        if bridge.isConnected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if nsView.window?.firstResponder !== nsView {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
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
                NSWorkspace.shared.open(url)
            }
        }

        func clipboardCopy(source: TerminalView, content: Data) {
            if let text = String(data: content, encoding: .utf8) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
#endif
