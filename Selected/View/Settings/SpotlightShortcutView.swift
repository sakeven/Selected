import SwiftUI
import Defaults

// Keep the shortcut binding in its own view to preserve Chinese input in Spotlight.
struct SpotlightShortcutView: View {
    @Default(.spotlightShortcut) private var spotlightShortcut

    var body: some View {
        HStack {
            Text("Spotlight HotKey").font(.subheadline)
            Spacer()
            ShortcutRecorderView(shortcut: $spotlightShortcut)
                .frame(width: 180, height: 28)
                .accessibilityLabel("Spotlight HotKey")
        }
    }
}
