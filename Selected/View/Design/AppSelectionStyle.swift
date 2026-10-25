import SwiftUI

struct AppSelectionStyle: ButtonStyle {
    var isSelected = false
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                    .fill(isSelected ? AppTheme.selection : isHovered || configuration.isPressed ? AppTheme.inset : .clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                    .strokeBorder(isSelected ? AppTheme.accent.opacity(0.25) : .clear)
            }
            .contentShape(.rect(cornerRadius: AppTheme.controlRadius))
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
    }
}
