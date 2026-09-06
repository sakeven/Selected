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
                        Text(plugin.info.version.map { String(localized: "Version \($0)") } ?? String(localized: "Unversioned"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Toggle("Enable Plugin", isOn: Binding(get: { plugin.info.enabled }, set: { manager.setEnabled($0, for: plugin) }))
                        .toggleStyle(.switch).labelsHidden()
                        .help(plugin.info.enabled ? String(localized: "Disable Plugin") : String(localized: "Enable Plugin"))
                }
                if let description = plugin.info.description, !description.isEmpty {
                    Text(description).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    Button("Edit Plugin", systemImage: "slider.horizontal.3", action: edit)
                        .buttonStyle(SettingsButtonStyle(emphasis: .primary))
                    Menu {
                        Button("Export Plugin…", systemImage: "square.and.arrow.up", action: exportPlugin)
                        Button("Show in Finder", systemImage: "folder") {
                            NSWorkspace.shared.activateFileViewerSelecting([manager.directory(for: plugin).appendingPathComponent("config.yaml")])
                        }
                        Divider()
                        Button("Restore Previous Version", systemImage: "clock.arrow.circlepath") { confirmRestore = true }
                            .disabled(!manager.hasPreviousVersion(plugin))
                        Divider()
                        Button("Delete Plugin…", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: {
                        HStack(spacing: 6) {
                            Text("More")
                            Image(systemName: "chevron.down").font(.caption)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(.primary.opacity(0.045), in: .rect(cornerRadius: 9))
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    Spacer()
                    Label(plugin.info.enabled ? String(localized: "Enabled") : String(localized: "Disabled"), systemImage: plugin.info.enabled ? "checkmark.circle" : "pause.circle")
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
                        Text("Configuration").font(.headline)
                        SettingsCard {
                            if plugin.info.options.isEmpty {
                                Label("Ready to use. No configuration needed.", systemImage: "checkmark.circle")
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
                            Text("Actions").font(.headline)
                            Text("\(plugin.actions.count)")
                                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(.primary.opacity(0.05), in: .capsule)
                        }
                        SettingsCard {
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
                            Label("Can run local commands", systemImage: "terminal").font(.caption).foregroundStyle(.secondary)
                        }
                        if plugin.actions.contains(where: { $0.gpt != nil }) {
                            Label("Uses the AI model and provider from General settings", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    DisclosureGroup("Plugin Information") {
                        VStack(alignment: .leading, spacing: 10) {
                            LabeledContent("Identifier", value: plugin.id).textSelection(.enabled)
                            LabeledContent("Schema Version", value: "\(plugin.schemaVersion ?? 1)")
                            if let minimum = plugin.info.minSelectedVersion { LabeledContent("Minimum Selected Version", value: minimum) }
                            Text(manager.hasPreviousVersion(plugin) ? String(localized: "The previous version is saved. Restore it from the More menu.") : String(localized: "The previous version is kept after editing or updating. Your settings are saved separately."))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                    }.font(.subheadline).foregroundStyle(.secondary)
                }.padding(24)
            }
        }
        .background(Color("SettingsBackground"))
        .tint(Color.blue)
        .disclosureGroupStyle(SettingsDisclosureGroupStyle())
        .confirmationDialog("Delete “\(plugin.info.name)”, its settings, and previous versions?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Plugin", role: .destructive) { perform { try manager.remove(plugin) } }
        }
        .confirmationDialog("Restore the previous version? This replaces the current plugin definition and keeps your settings.", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restore Previous Version") { perform { try manager.restorePreviousVersion(plugin) } }
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() } catch { reportError(error.localizedDescription) }
    }

    private func exportPlugin() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = plugin.info.name + ".selectedext"
        panel.message = String(localized: "Export the plugin definition and resources without personal settings or secrets. Choose a new filename.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform { try manager.export(plugin, to: url) }
    }
}
