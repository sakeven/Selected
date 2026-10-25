import SwiftUI

struct SettingsView: View {
    @State private var selection: SettingsDestination = .general

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 12) {
                    Image("SelectedMenuBar")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(AppTheme.onAccent)
                        .padding(10)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.accent, in: .rect(cornerRadius: 12))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "Selected").font(.title3.weight(.semibold))
                        Text("Settings").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)

                VStack(spacing: 6) {
                    ForEach(SettingsDestination.allCases) { destination in
                        Button { selection = destination } label: {
                            HStack(spacing: 12) {
                                Image(systemName: destination.icon)
                                    .frame(width: 20)
                                    .foregroundStyle(selection == destination ? AppTheme.accent : .secondary)
                                    .accessibilityHidden(true)
                                Text(destination.title)
                                    .font(.body.weight(selection == destination ? .semibold : .regular))
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                        }
                        .buttonStyle(AppSelectionStyle(isSelected: selection == destination))
                        .keyboardShortcut(destination.shortcut, modifiers: .command)
                        .accessibilityAddTraits(selection == destination ? .isSelected : [])
                        .accessibilityIdentifier("settings-\(destination.rawValue)")
                    }
                }

                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 10) {
                    Rectangle().fill(AppTheme.border).frame(height: 1)
                    ShortcutHint(keys: "⌘1–4", title: "settings.navigationHint")
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 14)
            .padding(.top, 28)
            .padding(.bottom, 20)
            .background(AppTheme.canvas)
            .frame(width: 210)

            Rectangle().fill(AppTheme.border).frame(width: 1)

            Group {
                switch selection {
                case .general: GeneralSettingsView()
                case .extensions: PluginListView()
                case .applications: ApplicationActionListView()
                case .clipboard: ClipboardSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(AppTheme.accent)
        .background(AppTheme.canvas)
        .frame(minWidth: 1000, idealWidth: 1080, minHeight: 640, idealHeight: 760)
    }
}

#Preview {
    SettingsView()
}
