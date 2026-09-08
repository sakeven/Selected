import SwiftUI

extension ColorScheme {
    var clipBackdropColors: [Color] {
        self == .dark
            ? [Color(red: 0.12, green: 0.14, blue: 0.18), Color(red: 0.09, green: 0.10, blue: 0.13)]
            : [Color(red: 0.96, green: 0.97, blue: 0.99), Color(red: 0.91, green: 0.93, blue: 0.96)]
    }

    var clipShellStroke: Color {
        self == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.8)
    }

    var clipPanelFill: Color {
        self == .dark ? Color.white.opacity(0.025) : Color.white.opacity(0.4)
    }

    var clipPanelStroke: Color {
        self == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    var clipCardFill: Color {
        self == .dark ? Color.white.opacity(0.035) : Color.white.opacity(0.7)
    }

    var clipPreviewFill: LinearGradient {
        LinearGradient(
            colors: self == .dark
                ? [Color.white.opacity(0.055), Color.white.opacity(0.025)]
                : [Color.white.opacity(0.36), Color.white.opacity(0.16)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var clipSelectedFill: Color {
        Color.accentColor.opacity(self == .dark ? 0.22 : 0.10)
    }

    var clipSelectedStroke: Color {
        Color.accentColor.opacity(self == .dark ? 0.55 : 0.35)
    }

    var clipDivider: Color {
        self == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
    }

    var clipPrimaryText: Color { .primary }
    var clipSecondaryText: Color { .secondary }

}
