import SwiftUI

// MARK: - mSSH Design System
// Minimal dark theme inspired by iTerm2 and modern terminal apps.

enum AppColors {
    // Core palette
    static let background = Color(red: 0.07, green: 0.07, blue: 0.09)        // Near-black
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.14)           // Card/cell background
    static let surfaceElevated = Color(red: 0.15, green: 0.15, blue: 0.18)   // Elevated surfaces
    static let border = Color.white.opacity(0.08)                              // Subtle borders
    static let borderActive = Color.white.opacity(0.15)                        // Active borders

    // Text
    static let textPrimary = Color(red: 0.93, green: 0.93, blue: 0.95)
    static let textSecondary = Color(red: 0.55, green: 0.55, blue: 0.60)
    static let textTertiary = Color(red: 0.35, green: 0.35, blue: 0.40)

    // Accent - Cyan/Teal
    static let accent = Color(red: 0.30, green: 0.85, blue: 0.85)
    static let accentDim = Color(red: 0.30, green: 0.85, blue: 0.85).opacity(0.15)

    // Status
    static let connected = Color(red: 0.30, green: 0.85, blue: 0.45)
    static let connectedDim = Color(red: 0.30, green: 0.85, blue: 0.45).opacity(0.15)
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.25)
    static let error = Color(red: 0.95, green: 0.30, blue: 0.30)
    static let errorDim = Color(red: 0.95, green: 0.30, blue: 0.30).opacity(0.15)

    // Terminal
    static let terminalBg = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let terminalCursor = accent
}

enum AppFonts {
    static let mono = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)
    static let monoCaption = Font.system(.caption2, design: .monospaced)
    static let monoLarge = Font.system(.title3, design: .monospaced).weight(.semibold)

    static let heading = Font.system(.title2, design: .default).weight(.semibold)
    static let subheading = Font.system(.subheadline, design: .default).weight(.medium)
    static let label = Font.system(.caption, design: .default).weight(.medium)
}

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Reusable Components

struct AppCardStyle: ViewModifier {
    var isActive: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isActive ? AppColors.borderActive : AppColors.border, lineWidth: 0.5)
            )
    }
}

struct AppSectionHeader: View {
    let title: String
    var count: Int? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundStyle(AppColors.textTertiary)
                .tracking(1.2)
            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(AppColors.accentDim)
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.xs)
    }
}

struct StatusDot: View {
    let isConnected: Bool

    var body: some View {
        Circle()
            .fill(isConnected ? AppColors.connected : AppColors.textTertiary)
            .frame(width: 8, height: 8)
            .shadow(color: isConnected ? AppColors.connected.opacity(0.5) : .clear, radius: 4)
    }
}

extension View {
    func appCard(isActive: Bool = false) -> some View {
        modifier(AppCardStyle(isActive: isActive))
    }
}

// MARK: - App Theme Modifier

struct AppThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .tint(AppColors.accent)
    }
}

extension View {
    func appTheme() -> some View {
        modifier(AppThemeModifier())
    }
}
