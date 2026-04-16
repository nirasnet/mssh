import SwiftUI

struct TerminalTheme: Equatable {
    var background: Color
    var foreground: Color
    var cursorColor: Color
    var name: String

    static let `default` = TerminalTheme(
        background: Color(red: 0.06, green: 0.06, blue: 0.08),
        foreground: Color(red: 0.88, green: 0.88, blue: 0.90),
        cursorColor: Color(red: 0.30, green: 0.85, blue: 0.85),
        name: "Default"
    )

    static let solarizedDark = TerminalTheme(
        background: Color(red: 0.0, green: 0.17, blue: 0.21),
        foreground: Color(red: 0.51, green: 0.58, blue: 0.59),
        cursorColor: Color(red: 0.52, green: 0.6, blue: 0.0),
        name: "Solarized Dark"
    )

    static let monokai = TerminalTheme(
        background: Color(red: 0.15, green: 0.15, blue: 0.15),
        foreground: Color(red: 0.97, green: 0.97, blue: 0.95),
        cursorColor: Color(red: 0.97, green: 0.15, blue: 0.31),
        name: "Monokai"
    )

    static let nord = TerminalTheme(
        background: Color(red: 0.18, green: 0.20, blue: 0.25),
        foreground: Color(red: 0.85, green: 0.87, blue: 0.91),
        cursorColor: Color(red: 0.53, green: 0.75, blue: 0.82),
        name: "Nord"
    )

    static let dracula = TerminalTheme(
        background: Color(red: 0.16, green: 0.16, blue: 0.21),
        foreground: Color(red: 0.97, green: 0.97, blue: 0.95),
        cursorColor: Color(red: 0.74, green: 0.58, blue: 0.98),
        name: "Dracula"
    )

    static let tokyoNight = TerminalTheme(
        background: Color(red: 0.10, green: 0.11, blue: 0.17),
        foreground: Color(red: 0.66, green: 0.70, blue: 0.84),
        cursorColor: Color(red: 0.49, green: 0.51, blue: 0.98),
        name: "Tokyo Night"
    )

    static let allThemes: [TerminalTheme] = [
        .default, .solarizedDark, .monokai, .nord, .dracula, .tokyoNight
    ]

    /// Look up a theme by its display name. Falls back to `.default` for
    /// unknown names so a stale UserDefaults value never crashes the UI.
    static func named(_ name: String) -> TerminalTheme {
        allThemes.first { $0.name == name } ?? .default
    }
}
