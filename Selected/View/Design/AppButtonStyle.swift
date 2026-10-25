import SwiftUI

struct AppButtonStyle: ButtonStyle {
    enum Emphasis { case prominent, primary, secondary, quiet, destructive }
    var emphasis: Emphasis = .secondary
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(controlSize == .small ? .callout.weight(.medium) : .body.weight(.medium))
            .padding(.horizontal, controlSize == .small || emphasis == .quiet ? 10 : 14)
            .padding(.vertical, controlSize == .small ? 6 : 9)
            .frame(minHeight: controlSize == .small ? 30 : 36)
            .foregroundStyle(configuration.role == .destructive ? Color.red : foreground)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                    .fill(background.opacity(configuration.isPressed ? 0.75 : 1))
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                    .strokeBorder(emphasis == .primary ? AppTheme.accent.opacity(0.2) : emphasis == .secondary ? AppTheme.border : .clear)
            }
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(.rect(cornerRadius: AppTheme.controlRadius))
            .onHover { isHovered = $0 }
    }

    private var foreground: Color {
        switch emphasis {
        case .prominent: AppTheme.onAccent
        case .primary: AppTheme.accent
        case .destructive: .red
        case .secondary, .quiet: .primary
        }
    }

    private var background: Color {
        switch emphasis {
        case .prominent: AppTheme.accent.opacity(isHovered ? 0.9 : 1)
        case .primary: isHovered ? AppTheme.accent.opacity(0.18) : AppTheme.selection
        case .secondary: isHovered ? AppTheme.inset : AppTheme.surface
        case .quiet: isHovered ? AppTheme.inset : .clear
        case .destructive: .red.opacity(isHovered ? 0.12 : 0.06)
        }
    }
}
