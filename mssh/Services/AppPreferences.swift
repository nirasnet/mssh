import Foundation
import SwiftUI
import Observation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Centralized, persistent app preferences.
///
/// Backed by `UserDefaults` so values survive launches and stay in sync with
/// `@AppStorage` reads from SwiftUI views (the keys here mirror the literal
/// strings used by `@AppStorage` throughout the codebase).
///
/// Use the `shared` singleton from non-SwiftUI code (services, the terminal
/// bridge, the accessory bar). SwiftUI views may continue to use
/// `@AppStorage(AppPreferences.Key.<name>)` directly — the values stay
/// coherent because both APIs read and write the same `UserDefaults` keys.
@Observable
final class AppPreferences {
    static let shared = AppPreferences()

    enum Key {
        static let terminalThemeName = "terminalThemeName"
        static let terminalFontFamily = "terminalFontFamily"
        static let terminalFontSize = "terminalFontSize"
        static let terminalCursorStyle = "terminalCursorStyle"
        static let terminalBlinkCursor = "terminalBlinkCursor"
    }

    enum Default {
        static let terminalThemeName = "Default"
        static let terminalFontFamily = "Menlo"
        static let terminalFontSize = 14
        static let terminalCursorStyle = "block"
        static let terminalBlinkCursor = true
    }

    enum CursorStyle: String, CaseIterable, Identifiable {
        case block
        case bar
        case underline

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .block: return "Block"
            case .bar: return "Bar"
            case .underline: return "Underline"
            }
        }
    }

    /// Curated list of monospaced families that ship with iOS and macOS.
    /// "System" maps to `monospacedSystemFont` (SF Mono on modern OSes).
    static let availableFontFamilies: [String] = [
        "System", "Menlo", "Courier New", "Monaco"
    ]

    static let fontSizeRange: ClosedRange<Int> = 9...24

    var terminalThemeName: String {
        didSet { UserDefaults.standard.set(terminalThemeName, forKey: Key.terminalThemeName) }
    }

    var terminalFontFamily: String {
        didSet { UserDefaults.standard.set(terminalFontFamily, forKey: Key.terminalFontFamily) }
    }

    var terminalFontSize: Int {
        didSet {
            let clamped = min(
                max(terminalFontSize, Self.fontSizeRange.lowerBound),
                Self.fontSizeRange.upperBound
            )
            if clamped != terminalFontSize {
                terminalFontSize = clamped
                return
            }
            UserDefaults.standard.set(terminalFontSize, forKey: Key.terminalFontSize)
        }
    }

    var terminalCursorStyle: String {
        didSet { UserDefaults.standard.set(terminalCursorStyle, forKey: Key.terminalCursorStyle) }
    }

    var terminalBlinkCursor: Bool {
        didSet { UserDefaults.standard.set(terminalBlinkCursor, forKey: Key.terminalBlinkCursor) }
    }

    private init() {
        let d = UserDefaults.standard
        self.terminalThemeName = d.string(forKey: Key.terminalThemeName) ?? Default.terminalThemeName
        self.terminalFontFamily = d.string(forKey: Key.terminalFontFamily) ?? Default.terminalFontFamily

        let storedSize = d.integer(forKey: Key.terminalFontSize)
        let resolvedSize = storedSize == 0 ? Default.terminalFontSize : storedSize
        self.terminalFontSize = min(
            max(resolvedSize, Self.fontSizeRange.lowerBound),
            Self.fontSizeRange.upperBound
        )

        self.terminalCursorStyle = d.string(forKey: Key.terminalCursorStyle) ?? Default.terminalCursorStyle

        if d.object(forKey: Key.terminalBlinkCursor) != nil {
            self.terminalBlinkCursor = d.bool(forKey: Key.terminalBlinkCursor)
        } else {
            self.terminalBlinkCursor = Default.terminalBlinkCursor
        }
    }

    var resolvedCursorStyle: CursorStyle {
        CursorStyle(rawValue: terminalCursorStyle) ?? .block
    }

    var resolvedTheme: TerminalTheme {
        TerminalTheme.named(terminalThemeName)
    }

    /// Resolve the user's font choice to a concrete platform font of the given
    /// size. Falls back to the system monospaced font when the named family
    /// isn't installed on the device.
    #if os(iOS)
    func resolvedFont(size: CGFloat? = nil) -> UIFont {
        let pt = size ?? CGFloat(terminalFontSize)
        if terminalFontFamily != "System",
           let f = UIFont(name: terminalFontFamily, size: pt) {
            return f
        }
        return UIFont.monospacedSystemFont(ofSize: pt, weight: .regular)
    }
    #elseif os(macOS)
    func resolvedFont(size: CGFloat? = nil) -> NSFont {
        let pt = size ?? CGFloat(terminalFontSize)
        if terminalFontFamily != "System",
           let f = NSFont(name: terminalFontFamily, size: pt) {
            return f
        }
        return NSFont.monospacedSystemFont(ofSize: pt, weight: .regular)
    }
    #endif
}
