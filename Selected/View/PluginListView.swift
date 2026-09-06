import SwiftUI

struct PluginListView: View {
    @ObservedObject private var pluginMgr: PluginManager
    @State private var selection: String?
    @State private var editor: PluginEditorSession?
    @State private var errorMessage: String?
    @State private var repairIssue: PluginLoadIssue?
    @State private var popclipImport: PopClipImport?
    @State private var isImporting = false

    init(manager: PluginManager = .shared) {
        pluginMgr = manager
    }

    private var selectedPlugin: Plugin? { pluginMgr.plugins.first { $0.id == selection } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SettingsPageHeader(title: "Plugins", subtitle: "\(pluginMgr.plugins.count) installed · Do more with selected text")
                Button("Import…", systemImage: "square.and.arrow.down", action: importPlugin)
                    .buttonStyle(SettingsButtonStyle())
                    .disabled(isImporting)
                if isImporting { ProgressView().controlSize(.small) }
                Button("New Plugin", systemImage: "plus") {
                    editor = PluginEditorSession(plugin: .new(), existing: nil)
                }
                .buttonStyle(SettingsButtonStyle(emphasis: .primary))
                Menu {
                    Button("Reload", systemImage: "arrow.clockwise") { pluginMgr.loadPlugins() }
                    Button("Open Plugins Folder", systemImage: "folder") { NSWorkspace.shared.open(pluginMgr.extensionsDir) }
                } label: {
                    Label("More plugin management actions", systemImage: "ellipsis")
                        .labelStyle(.iconOnly).frame(width: 30, height: 32)
                        .contentShape(.rect)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("More plugin management actions")
            }
            .controlSize(.large)
            .padding(20)
            Divider()
            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Installed").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            .padding(.horizontal, 12).padding(.bottom, 4)
                        ForEach(pluginMgr.plugins) { plugin in
                            Button {
                                selection = plugin.id
                            } label: {
                                HStack(spacing: 10) {
                                    Icon(plugin.info.icon)
                                        .foregroundStyle(selection == plugin.id ? Color.blue : .secondary)
                                        .frame(width: 38, height: 38)
                                        .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 10))
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(plugin.info.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                        Text("\(plugin.actions.count) actions · \(plugin.info.version.map { "v" + $0 } ?? String(localized: "Unversioned"))")
                                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if !plugin.info.enabled { Image(systemName: "pause.circle").foregroundStyle(.secondary).accessibilityLabel("Disabled") }
                                    if plugin.compatibilityIssue(hostVersion: pluginMgr.hostVersion) != nil {
                                        Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).accessibilityLabel("Incompatible Version")
                                    } else if !plugin.info.missingOptions().isEmpty {
                                        Image(systemName: "slider.horizontal.3").foregroundStyle(.orange).accessibilityLabel("Needs Configuration")
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selection == plugin.id ? Color.blue.opacity(0.09) : .clear, in: .rect(cornerRadius: 12))
                                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(selection == plugin.id ? Color.blue.opacity(0.15) : .clear) }
                                .contentShape(.rect(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selection == plugin.id ? .isSelected : [])
                        }
                    }.padding(12)
                }
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)
                if let plugin = selectedPlugin {
                    PluginDetailView(plugin: plugin, manager: pluginMgr, edit: {
                        do { editor = PluginEditorSession(plugin: try pluginMgr.manifest(for: plugin), existing: plugin) }
                        catch { errorMessage = error.localizedDescription }
                    }, reportError: { errorMessage = $0 })
                    .id(plugin.id + "-" + (plugin.info.version ?? ""))
                    .frame(minWidth: 370, maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label("Get Started with Plugins", systemImage: "puzzlepiece.extension")
                    } description: {
                        Text("Create your own text actions or import an existing plugin.")
                    } actions: {
                        Button("New Plugin", systemImage: "plus") {
                            editor = PluginEditorSession(plugin: .new(), existing: nil)
                        }.buttonStyle(SettingsButtonStyle(emphasis: .primary))
                    }
                        .frame(minWidth: 370, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            if !pluginMgr.loadIssues.isEmpty {
                Divider()
                DisclosureGroup("\(pluginMgr.loadIssues.count) plugins failed to load") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(pluginMgr.loadIssues) { issue in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(issue.directory.lastPathComponent).fontWeight(.medium)
                                        Text(issue.message).textSelection(.enabled)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    Button("Repair…", systemImage: "wrench") { repairIssue = issue }
                                        .buttonStyle(SettingsButtonStyle())
                                }
                            }
                        }.font(.caption)
                    }.frame(maxHeight: 100)
                }.padding(12).foregroundStyle(.red)
            }
        }
        .background(Color("SettingsBackground"))
        .tint(Color.blue)
        .disclosureGroupStyle(SettingsDisclosureGroupStyle())
        .frame(minWidth: 760, minHeight: 560)
        .onChange(of: pluginMgr.plugins.map(\.id), initial: true) {
            if !pluginMgr.plugins.contains(where: { $0.id == selection }) {
                selection = pluginMgr.plugins.first?.id
            }
        }
        .sheet(item: $editor) { session in
            PluginEditorView(session: session, manager: pluginMgr) { id in selection = id }
        }
        .sheet(item: $repairIssue) { issue in
            PluginRepairView(issue: issue, manager: pluginMgr) { selection = $0 }
        }
        .sheet(item: $popclipImport) { session in
            PopClipImportView(session: session, manager: pluginMgr) { selection = $0 }
        }
        .alert("Plugin Operation Failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func importPlugin() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose a Selected plugin, a .popclipext package, or a .popclipextz archive.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if ["popclipext", "popclipextz"].contains(url.pathExtension.lowercased()) {
            isImporting = true
            Task {
                defer { isImporting = false }
                do { popclipImport = try await Task.detached { try PopClipImporter.inspect(url) }.value }
                catch { errorMessage = error.localizedDescription }
            }
            return
        }
        do {
            try pluginMgr.install(url: url)
            selection = try pluginMgr.readManifest(at: url).id
        } catch { errorMessage = error.localizedDescription }
    }
}
