import SwiftUI

struct PluginListView: View {
    @ObservedObject private var pluginMgr: PluginManager
    @State private var selection: String?
    @State private var editor: PluginEditorSession?
    @State private var errorMessage: String?

    init(manager: PluginManager = .shared) {
        pluginMgr = manager
    }

    private var selectedPlugin: Plugin? { pluginMgr.plugins.first { $0.id == selection } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("插件").font(.title2.bold())
                    Text("\(pluginMgr.plugins.count) 个已安装 · 让选中文字更有用")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("导入…", systemImage: "square.and.arrow.down", action: importPlugin)
                    .buttonStyle(PluginButtonStyle())
                Button("新建插件", systemImage: "plus") {
                    editor = PluginEditorSession(plugin: .new(), existing: nil)
                }
                .buttonStyle(PluginButtonStyle(emphasis: .primary))
                Menu {
                    Button("重新加载", systemImage: "arrow.clockwise") { pluginMgr.loadPlugins() }
                    Button("打开插件文件夹", systemImage: "folder") { NSWorkspace.shared.open(pluginMgr.extensionsDir) }
                } label: {
                    Label("更多插件管理操作", systemImage: "ellipsis")
                        .labelStyle(.iconOnly).frame(width: 30, height: 32)
                        .contentShape(.rect)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("更多插件管理操作")
            }
            .controlSize(.large)
            .padding(20)
            Divider()
            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("已安装").font(.caption.weight(.medium)).foregroundStyle(.secondary)
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
                                        Text("\(plugin.actions.count) 个动作 · " + (plugin.info.version.map { "v" + $0 } ?? "未标记版本"))
                                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if !plugin.info.enabled { Image(systemName: "pause.circle").foregroundStyle(.secondary).accessibilityLabel("已停用") }
                                    if plugin.compatibilityIssue(hostVersion: pluginMgr.hostVersion) != nil {
                                        Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).accessibilityLabel("版本不兼容")
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
                        Label("开始使用插件", systemImage: "puzzlepiece.extension")
                    } description: {
                        Text("创建自己的文字操作，或导入已有插件。")
                    } actions: {
                        Button("新建插件", systemImage: "plus") {
                            editor = PluginEditorSession(plugin: .new(), existing: nil)
                        }.buttonStyle(PluginButtonStyle(emphasis: .primary))
                    }
                        .frame(minWidth: 370, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            if !pluginMgr.loadIssues.isEmpty {
                Divider()
                DisclosureGroup("\(pluginMgr.loadIssues.count) 个插件加载失败") {
                    ScrollView {
                        Text(pluginMgr.loadIssues.joined(separator: "\n\n"))
                            .font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 100)
                }.padding(12).foregroundStyle(.red)
            }
        }
        .background(Color("PluginBackground"))
        .tint(Color.blue)
        .disclosureGroupStyle(PluginDisclosureGroupStyle())
        .frame(minWidth: 760, minHeight: 560)
        .onChange(of: pluginMgr.plugins.map(\.id), initial: true) {
            if !pluginMgr.plugins.contains(where: { $0.id == selection }) {
                selection = pluginMgr.plugins.first?.id
            }
        }
        .sheet(item: $editor) { session in
            PluginEditorView(session: session, manager: pluginMgr) { id in selection = id }
        }
        .alert("插件操作失败", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func importPlugin() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "选择包含 config.yaml 的 .selectedext 插件包或文件夹。"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try pluginMgr.install(url: url)
            selection = try pluginMgr.readManifest(at: url).id
        } catch { errorMessage = error.localizedDescription }
    }
}

struct ActionListView: View {
    @ObservedObject private var pluginMgr = PluginManager.shared

    var body: some View {
        List(pluginMgr.allActions, id: \.actionMeta.identifier) { action in
            HStack {
                Icon(action.actionMeta.icon)
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.actionMeta.title)
                    if let description = action.actionMeta.description {
                        Text(description).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.padding(10)
        }
    }
}
