import SwiftUI
import SwiftTerm

/// DECSCUSR cursor-shape escape sequence for the user's preference.
/// `\e[N q` where N is 1-6 (block/underline/bar × blink/steady).
/// Lives at file scope so iOS and macOS wrappers share one source of truth.
private func decscusrEscape(style: AppPreferences.CursorStyle, blink: Bool) -> [UInt8] {
    let code: Int
    switch (style, blink) {
    case (.block, true):      code = 1
    case (.block, false):     code = 2
    case (.underline, true):  code = 3
    case (.underline, false): code = 4
    case (.bar, true):        code = 5
    case (.bar, false):       code = 6
    }
    return Array("\u{1B}[\(code) q".utf8)
}

#if os(iOS)
/// UIViewRepresentable wrapper for SwiftTerm's TerminalView (iOS)
struct TerminalViewWrapper: UIViewRepresentable {
    @ObservedObject var bridge: SSHTerminalBridge
    @AppStorage(AppPreferences.Key.terminalThemeName)
    private var themeName = AppPreferences.Default.terminalThemeName
    @AppStorage(AppPreferences.Key.terminalFontFamily)
    private var fontFamily = AppPreferences.Default.terminalFontFamily
    @AppStorage(AppPreferences.Key.terminalFontSize)
    private var fontSize = AppPreferences.Default.terminalFontSize
    @AppStorage(AppPreferences.Key.terminalCursorStyle)
    private var cursorStyleRaw = AppPreferences.Default.terminalCursorStyle
    @AppStorage(AppPreferences.Key.terminalBlinkCursor)
    private var blinkCursor = AppPreferences.Default.terminalBlinkCursor

    private var theme: TerminalTheme { TerminalTheme.named(themeName) }

    private var resolvedFont: UIFont {
        let pt = CGFloat(fontSize)
        if fontFamily != "System", let f = UIFont(name: fontFamily, size: pt) {
            return f
        }
        return UIFont.monospacedSystemFont(ofSize: pt, weight: .regular)
    }

    func makeUIView(context: Context) -> TerminalView {
        let terminal = TerminalView()
        terminal.terminalDelegate = context.coordinator
        terminal.nativeBackgroundColor = UIColor(theme.background)
        terminal.nativeForegroundColor = UIColor(theme.foreground)
        terminal.font = resolvedFont
        terminal.inputAccessoryView = TerminalAccessoryBar(terminal: terminal)
        bridge.terminalView = terminal

        applyCursorStyle(to: terminal)

        if bridge.isConnected {
            Self.focusWithRetry(terminal)
        }

        return terminal
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        uiView.nativeBackgroundColor = UIColor(theme.background)
        uiView.nativeForegroundColor = UIColor(theme.foreground)

        let target = resolvedFont
        if uiView.font.fontName != target.fontName
            || abs(uiView.font.pointSize - target.pointSize) > 0.5 {
            uiView.font = target
        }

        applyCursorStyle(to: uiView)

        if bridge.isConnected && !uiView.isFirstResponder {
            Self.focusWithRetry(uiView)
        }
    }

    /// Apply the user's cursor preference. `feed(byteArray:)` is public on
    /// both platforms; SwiftTerm's `terminal` property is internal on iOS.
    private func applyCursorStyle(to terminal: TerminalView) {
        let style = AppPreferences.CursorStyle(rawValue: cursorStyleRaw) ?? .block
        terminal.feed(byteArray: ArraySlice(decscusrEscape(style: style, blink: blinkCursor)))
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
    @AppStorage(AppPreferences.Key.terminalThemeName)
    private var themeName = AppPreferences.Default.terminalThemeName
    @AppStorage(AppPreferences.Key.terminalFontFamily)
    private var fontFamily = AppPreferences.Default.terminalFontFamily
    @AppStorage(AppPreferences.Key.terminalFontSize)
    private var fontSize = AppPreferences.Default.terminalFontSize
    @AppStorage(AppPreferences.Key.terminalCursorStyle)
    private var cursorStyleRaw = AppPreferences.Default.terminalCursorStyle
    @AppStorage(AppPreferences.Key.terminalBlinkCursor)
    private var blinkCursor = AppPreferences.Default.terminalBlinkCursor

    private var theme: TerminalTheme { TerminalTheme.named(themeName) }

    private var resolvedFont: NSFont {
        let pt = CGFloat(fontSize)
        if fontFamily != "System", let f = NSFont(name: fontFamily, size: pt) {
            return f
        }
        return NSFont.monospacedSystemFont(ofSize: pt, weight: .regular)
    }

    func makeNSView(context: Context) -> TerminalView {
        let terminal = TerminalView()
        terminal.terminalDelegate = context.coordinator
        terminal.nativeBackgroundColor = NSColor(theme.background)
        terminal.nativeForegroundColor = NSColor(theme.foreground)
        terminal.font = resolvedFont
        bridge.terminalView = terminal

        applyCursorStyle(to: terminal)

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

        let target = resolvedFont
        if nsView.font.fontName != target.fontName
            || abs(nsView.font.pointSize - target.pointSize) > 0.5 {
            nsView.font = target
        }

        applyCursorStyle(to: nsView)

        if bridge.isConnected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if nsView.window?.firstResponder !== nsView {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        }
    }

    /// Apply cursor style via DECSCUSR (shared with iOS).
    private func applyCursorStyle(to terminal: TerminalView) {
        let style = AppPreferences.CursorStyle(rawValue: cursorStyleRaw) ?? .block
        terminal.feed(byteArray: ArraySlice(decscusrEscape(style: style, blink: blinkCursor)))
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
