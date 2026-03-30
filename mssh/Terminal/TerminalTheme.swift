import SwiftUI

struct TerminalTheme: Equatable {
    var background: Color
    var foreground: Color
    var cursorColor: Color
    var name: String

    static let `default` = TerminalTheme(
        background: Color(red: 0.1, green: 0.1, blue: 0.12),
        foreground: Color(red: 0.9, green: 0.9, blue: 0.9),
        cursorColor: .green,
        name: "Default"
    )

    static let solarizedDark = TerminalTheme(
        background: Color(red: 0.0, green: 0.17, blue: 0.21),
        foreground: Color(red: 0.51, green: 0.58, blue: 0.59),
        cursorColor: Color(red: 0.52, green: 0.6, blue: 0.0),
        name: "Solarized Dark"
    )

    static let monokai = TerminalTheme(
        background: Color(red: 0.16, green: 0.16, blue: 0.16),
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

    static let allThemes: [TerminalTheme] = [.default, .solarizedDark, .monokai, .nord]
}
