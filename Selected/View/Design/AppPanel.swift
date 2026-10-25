import SwiftUI

struct AppPanel: ViewModifier {
    var cornerRadius: CGFloat = AppTheme.panelRadius

    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .tint(AppTheme.accent)
    }
}
