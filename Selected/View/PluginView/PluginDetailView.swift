import SwiftUI

struct PluginDetailView: View {
    let plugin: Plugin
    @ObservedObject var manager: PluginManager
    let edit: () -> Void
    let reportError: (String) -> Void
    @State private var confirmDelete = false
    @State private var confirmRestore = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Icon(plugin.info.icon)
                        .foregroundStyle(Color.blue)
                        .frame(width: 48, height: 48)
                        .background(Color.blue.opacity(0.10), in: .rect(cornerRadius: 12))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(plugin.info.name).font(.title2.bold())
                        Text(plugin.info.version.map { "版本 " + $0 } ?? "未标记版本")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Toggle("启用插件", isOn: Binding(get: { plugin.info.enabled }, set: { manager.setEnabled($0, for: plugin) }))
                        .toggleStyle(.switch).labelsHidden()
                        .help(plugin.info.enabled ? "停用插件" : "启用插件")
                }
                if let description = plugin.info.description, !description.isEmpty {
                    Text(description).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    Button("编辑插件", systemImage: "slider.horizontal.3", action: edit)
                        .buttonStyle(PluginButtonStyle(emphasis: .primary))
                    Menu {
                        Button("导出插件…", systemImage: "square.and.arrow.up", action: exportPlugin)
                        Button("在 Finder 中显示", systemImage: "folder") {
                            NSWorkspace.shared.activateFileViewerSelecting([manager.directory(for: plugin).appendingPathComponent("config.yaml")])
                        }
                        Divider()
                        Button("恢复上一版本", systemImage: "clock.arrow.circlepath") { confirmRestore = true }
                            .disabled(!manager.hasPreviousVersion(plugin))
                        Divider()
                        Button("删除插件…", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: {
                        HStack(spacing: 6) {
                            Text("更多")
                            Image(systemName: "chevron.down").font(.caption)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(.primary.opacity(0.045), in: .rect(cornerRadius: 9))
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    Spacer()
                    Label(plugin.info.enabled ? "已启用" : "已停用", systemImage: plugin.info.enabled ? "checkmark.circle" : "pause.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }.controlSize(.large)
            }
            .padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let issue = plugin.compatibilityIssue(hostVersion: manager.hostVersion) {
                        Label(issue, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange).padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.orange.opacity(0.08), in: .rect(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("配置").font(.headline)
                        PluginCard {
                            if plugin.info.options.isEmpty {
                                Label("无需配置，可以直接使用。", systemImage: "checkmark.circle")
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(plugin.info.options) { option in
                                PluginOptionValueView(pluginID: plugin.id, option: option, manager: manager)
                                if option.id != plugin.info.options.last?.id { Divider().opacity(0.5) }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("动作").font(.headline)
                            Text("\(plugin.actions.count)")
                                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(.primary.opacity(0.05), in: .capsule)
                        }
                        PluginCard {
                            ForEach(plugin.actions) { action in
                                HStack(spacing: 10) {
                                    Icon(action.meta.icon).foregroundStyle(Color.blue).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(action.meta.title).font(.subheadline.weight(.medium))
                                        if let description = action.meta.description, !description.isEmpty {
                                            Text(description).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text(action.kind.title).font(.caption).foregroundStyle(.secondary)
                                }
                                if action.id != plugin.actions.last?.id { Divider().opacity(0.5) }
                            }
                        }
                        if plugin.actions.contains(where: { $0.runCommand != nil || $0.gpt?.tools?.contains(where: { $0.command != nil }) == true }) {
                            Label("可运行本机命令", systemImage: "terminal").font(.caption).foregroundStyle(.secondary)
                        }
                        if plugin.actions.contains(where: { $0.gpt != nil }) {
                            Label("使用通用设置中的 AI 模型与服务", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    DisclosureGroup("插件信息") {
                        VStack(alignment: .leading, spacing: 10) {
                            LabeledContent("标识", value: plugin.id).textSelection(.enabled)
                            LabeledContent("协议版本", value: "\(plugin.schemaVersion ?? 1)")
                            if let minimum = plugin.info.minSelectedVersion { LabeledContent("最低 Selected 版本", value: minimum) }
                            Text(manager.hasPreviousVersion(plugin) ? "已保留上一版本，可通过“更多”菜单恢复。" : "编辑或更新后会保留上一版本，个人参数独立保存。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                    }.font(.subheadline).foregroundStyle(.secondary)
                }.padding(24)
            }
        }
        .background(Color("PluginBackground"))
        .tint(Color.blue)
        .disclosureGroupStyle(PluginDisclosureGroupStyle())
        .confirmationDialog("删除“\(plugin.info.name)”及其参数和历史版本？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除插件", role: .destructive) { perform { try manager.remove(plugin) } }
        }
        .confirmationDialog("恢复上一版本？当前插件定义将被替换，个人参数保留。", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("恢复上一版本") { perform { try manager.restorePreviousVersion(plugin) } }
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { reportError(error.localizedDescription) }
    }

    private func exportPlugin() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = plugin.info.name + ".selectedext"
        panel.message = "导出插件定义与资源，不包含个人参数和密钥。请选择一个新文件名。"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform { try manager.export(plugin, to: url) }
    }
}
