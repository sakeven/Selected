import SwiftUI

struct PluginButtonStyle: ButtonStyle {
    enum Emphasis { case primary, secondary, quiet, destructive }
    var emphasis: Emphasis = .secondary
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .padding(.horizontal, emphasis == .quiet ? 10 : 15)
            .padding(.vertical, 9)
            .foregroundStyle(foreground)
            .background {
                RoundedRectangle(cornerRadius: 9)
                    .fill(background.opacity(configuration.isPressed ? 0.75 : 1))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(emphasis == .primary ? Color.blue.opacity(0.18) : emphasis == .secondary ? Color.primary.opacity(0.08) : .clear)
            }
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(.rect(cornerRadius: 9))
            .onHover { isHovered = $0 }
    }

    private var foreground: Color {
        switch emphasis {
        case .primary: return Color.blue
        case .destructive: return .red
        case .secondary, .quiet: return .primary
        }
    }

    private var background: Color {
        switch emphasis {
        case .primary: return Color.blue.opacity(colorScheme == .dark ? (isHovered ? 0.24 : 0.16) : (isHovered ? 0.18 : 0.10))
        case .secondary: return isHovered ? Color.primary.opacity(0.07) : Color(nsColor: .controlBackgroundColor)
        case .quiet: return Color.primary.opacity(isHovered ? 0.06 : 0)
        case .destructive: return Color.red.opacity(isHovered ? 0.12 : 0.06)
        }
    }
}
