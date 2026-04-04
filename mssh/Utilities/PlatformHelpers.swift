import SwiftUI

// MARK: - Cross-platform clipboard

enum AppClipboard {
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    static func paste() -> String? {
        #if os(iOS)
        return UIPasteboard.general.string
        #elseif os(macOS)
        return NSPasteboard.general.string(forType: .string)
        #endif
    }
}

// MARK: - Cross-platform view modifiers

extension View {
    @ViewBuilder
    func iOSOnlyNavigationBarTitleDisplayMode() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func iOSOnlyTextInputAutocapitalization(_ autocap: Bool = false) -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(autocap ? .sentences : .never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func iOSOnlyKeyboardType(_ type: Any? = nil) -> some View {
        #if os(iOS)
        if let keyboardType = type as? UIKeyboardType {
            self.keyboardType(keyboardType)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
