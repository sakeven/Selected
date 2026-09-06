import SwiftUI

struct PopClipImportView: View {
    @Environment(\.dismiss) private var dismiss
    let session: PopClipImport
    let manager: PluginManager
    let didSave: (String) -> Void
    private let existing: Plugin?
    @State private var draft: Plugin?
    @State private var errorMessage: String?

    init(session: PopClipImport, manager: PluginManager, didSave: @escaping (String) -> Void) {
        self.session = session
        self.manager = manager
        self.didSave = didSave
        existing = manager.plugins.first { $0.id == session.plugin?.id }
        var plugin = session.plugin
        if let existing { plugin?.info.version = existing.info.version.flatMap(PluginVersion.init)?.nextPatch ?? "1.0.0" }
        _draft = State(initialValue: plugin)
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsPageHeader(title: "Import from PopClip", subtitle: "Review compatibility before adding the plugin to Selected.").padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsCard {
                        HStack(spacing: 12) {
                            if let icon = draft?.info.icon {
                                Icon(icon.hasPrefix("file://./") ? "file://" + session.directory.appendingPathComponent(String(icon.dropFirst(9))).path : icon)
                                    .foregroundStyle(.blue).frame(width: 42, height: 42)
                                    .background(Color.blue.opacity(0.09), in: .rect(cornerRadius: 10))
                                    .accessibilityHidden(true)
                            }
                            Text(draft?.info.name ?? session.sourceName).font(.title2.bold())
                        }
                        if let draft {
                            Label("Compatible with this import", systemImage: "checkmark.circle").foregroundStyle(.blue)
                            if let description = draft.info.description { Text(description).foregroundStyle(.secondary) }
                            ForEach(draft.actions) { action in
                                HStack {
                                    Text(action.meta.title)
                                    Spacer()
                                    Text(action.kind.title).foregroundStyle(.secondary)
                                }
                            }
                            if !draft.info.options.isEmpty {
                                Divider()
                                Label("\(draft.info.options.count) options available after import", systemImage: "slider.horizontal.3")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        ForEach(session.issues, id: \.self) { issue in
                            Label(issue, systemImage: "exclamationmark.circle").foregroundStyle(.orange).textSelection(.enabled)
                        }
                    }
                    if !session.notes.isEmpty {
                        SettingsCard {
                            ForEach(Array(Set(session.notes)).sorted(), id: \.self) { note in
                                Label(note, systemImage: "info.circle").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let existing {
                        SettingsCard {
                            Label("Replace the installed plugin", systemImage: "arrow.triangle.2.circlepath").font(.headline)
                            Text("Local version \(existing.info.version ?? "") → \(draft?.info.version ?? "")")
                            Text("This replaces the current definition, including local edits. Your settings and a previous-version backup are kept.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if draft == nil {
                        Text("This first release supports declarative URL, keyboard shortcut, and plain-text macOS service actions. Script runtimes and other unsupported capabilities are listed above.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red).textSelection(.enabled) }
                }.padding(24)
            }
            Divider()
            HStack {
                Button("View Original Source", systemImage: "folder") {
                    NSWorkspace.shared.open(session.directory.appendingPathComponent("PopClip Source"))
                }.buttonStyle(SettingsButtonStyle())
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.buttonStyle(SettingsButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Import into Selected", systemImage: "square.and.arrow.down") {
                    guard let draft else { return }
                    do {
                        try manager.save(draft, replacing: existing, resources: session.directory)
                        didSave(draft.id)
                        dismiss()
                    } catch { errorMessage = error.localizedDescription }
                }.buttonStyle(SettingsButtonStyle(emphasis: .primary)).disabled(draft == nil || !session.issues.isEmpty)
            }.padding(20)
        }
        .frame(width: 680, height: 640)
        .background(Color("SettingsBackground")).tint(.blue)
    }
}
