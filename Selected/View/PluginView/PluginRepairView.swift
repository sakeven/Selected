import SwiftUI

struct PluginRepairView: View {
    @Environment(\.dismiss) private var dismiss
    let issue: PluginLoadIssue
    let manager: PluginManager
    let didSave: (String) -> Void
    @State private var source = ""
    @State private var original: Data?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsPageHeader(title: "Repair Plugin", subtitle: "Fix the source, then validate and reload the plugin.")
            Text(issue.directory.lastPathComponent).font(.headline)
            Text(issue.message).font(.caption).foregroundStyle(.orange).textSelection(.enabled).lineLimit(5)
            TextEditor(text: $source)
                .font(.system(.body, design: .monospaced)).autocorrectionDisabled().scrollContentBackground(.hidden)
                .padding(12).background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 12))
                .accessibilityLabel("Plugin YAML Definition")
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red).textSelection(.enabled).lineLimit(5) }
            HStack {
                Button("Show in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([issue.directory]) }
                    .buttonStyle(SettingsButtonStyle())
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.buttonStyle(SettingsButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Save and Reload", systemImage: "checkmark") {
                    guard let original else { return }
                    do {
                        didSave(try manager.repair(source, issue: issue, original: original))
                        dismiss()
                    } catch { errorMessage = error.localizedDescription }
                }.buttonStyle(SettingsButtonStyle(emphasis: .primary)).disabled(original == nil)
            }
        }
        .padding(24).frame(width: 720, height: 640)
        .background(Color("SettingsBackground")).tint(.blue)
        .interactiveDismissDisabled()
        .onAppear {
            do {
                let data = try Data(contentsOf: issue.directory.appendingPathComponent("config.yaml"))
                guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
                original = data
                source = text
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
