import SwiftUI

struct AppIconButtonStyle: ButtonStyle {
    var isSelected = false
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.body.weight(.medium))
            .foregroundStyle(configuration.role == .destructive && isHovered ? Color.red : isSelected ? AppTheme.accent : .secondary)
            .frame(minWidth: 32, minHeight: 32)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                    .fill(isSelected ? AppTheme.selection : isHovered || configuration.isPressed ? AppTheme.inset : .clear)
            }
            .contentShape(.rect(cornerRadius: AppTheme.controlRadius))
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
    }
}
