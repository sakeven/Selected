import SwiftUI
import Defaults

struct ClipboardSettingsView: View {
    @Default(.clipboardShortcut) private var shortcut
    @Default(.enableClipboard) private var enableClipboard
    @Default(.clipboardHistoryTime) private var keepTime

    var body: some View {
        SettingsPage(title: "Clipboard", subtitle: "设置剪贴板历史记录、唤出快捷键与保留时间。") {
            SettingsSection(title: "历史记录") {
                HStack {
                    Text("Clipboard History").font(.subheadline)
                    Spacer()
                    Toggle("Clipboard History", isOn: $enableClipboard).labelsHidden()
                }
                Divider().opacity(0.5)
                HStack {
                    Text("HotKey").font(.subheadline)
                    Spacer()
                    ShortcutRecorderView(shortcut: $shortcut)
                        .frame(width: 180, height: 28)
                        .accessibilityLabel("HotKey")
                }
                Divider().opacity(0.5)
                SettingsMenuPicker(title: String(localized: "Keep History For"), values: ClipboardHistoryTime.allCases, selection: $keepTime) {
                    NSLocalizedString($0.rawValue, comment: "Clipboard history duration")
                }
                .onChange(of: keepTime) { PersistenceController.shared.cleanTask() }
            }
        }
    }
}
