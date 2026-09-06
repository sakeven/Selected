import SwiftUI

struct ApplicationActionListView: View {
    @State private var cfg = ConfigurationManager.shared.userConfiguration
    @State private var defaultAppCondition = AppCondition(bundleID: "Default", actions: ConfigurationManager.shared.userConfiguration.defaultActions)
    @State private var isAddingApplication = false
    @State private var availableApplications: [Application] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SettingsPageHeader(title: "Applications", subtitle: "为不同应用选择工具栏中的动作与显示顺序。")
                Button("添加应用", systemImage: "plus") {
                    availableApplications = getAllApplications()
                    isAddingApplication = true
                }
                .buttonStyle(SettingsButtonStyle(emphasis: .primary))
                .popover(isPresented: $isAddingApplication, arrowEdge: .bottom) {
                    ApplicationPickerView(applications: availableApplications) { app in
                        isAddingApplication = false
                        cfg.appConditions.append(AppCondition(bundleID: app.id, actions: []))
                        ConfigurationManager.shared.userConfiguration = cfg
                        ConfigurationManager.shared.saveConfiguration()
                    }
                }
            }.padding(20)
            Divider()
            List {
                ApplicationView(cfg: $cfg, app: $defaultAppCondition)
                ForEach($cfg.appConditions, id: \.bundleID) { $app in
                    ApplicationView(cfg: $cfg, app: $app)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.vertical, 16, for: .scrollContent)
        }
        .background(Color("SettingsBackground"))
        .tint(.blue)
        .disclosureGroupStyle(SettingsDisclosureGroupStyle())
    }

    private func getAllApplications() -> [Application] {
        var apps: [String: Application] = [:]
        let fileManager = FileManager.default
        let directories = [URL(fileURLWithPath: "/Applications"),
                           fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
                           URL(fileURLWithPath: "/System/Applications")]
        for directory in directories {
            guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                guard let identifier = Bundle(url: url)?.bundleIdentifier, apps[identifier] == nil else { continue }
                apps[identifier] = Application(id: identifier,
                                               icon: Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)),
                                               localizedName: fileManager.displayName(atPath: url.path), isRunning: false)
            }
        }
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier else { continue }
            if apps[id] != nil {
                apps[id]?.isRunning = true
            } else if app.activationPolicy == .regular, let icon = app.icon, let name = app.localizedName {
                apps[id] = Application(id: id, icon: Image(nsImage: icon), localizedName: name, isRunning: true)
            }
        }
        for app in cfg.appConditions { apps.removeValue(forKey: app.bundleID) }
        return apps.values.sorted {
            if $0.isRunning != $1.isRunning { return $0.isRunning }
            return $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending
        }
    }
}

struct ApplicationView: View {
    @Binding var cfg: UserConfiguration
    @Binding var app: AppCondition
    @State private var dropTarget: ActionID?

    private func getAction(_ id: String) -> PerformAction? {
        GetAllActions().first { $0.actionMeta.identifier == id }
    }

    var body: some View {
        SettingsCard {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().opacity(0.5)
                    if app.actions.isEmpty {
                        Text(app.bundleID == "Default" ? "未限制动作，显示全部可用操作。" : "未单独配置动作，沿用默认设置。")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                    ForEach(app.actions, id: \.self) { id in
                        if let action = getAction(id) {
                            HStack(spacing: 12) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.caption).foregroundStyle(.tertiary)
                                    .help("拖动调整顺序").accessibilityHidden(true)
                                Icon(action.actionMeta.icon)
                                    .foregroundStyle(.blue)
                                    .frame(width: 30, height: 30)
                                    .background(.blue.opacity(0.08), in: .rect(cornerRadius: 8))
                                    .accessibilityHidden(true)
                                Text(action.actionMeta.title).font(.subheadline)
                                Spacer()
                                Button("上移", systemImage: "arrow.up") { move(id, by: -1) }
                                    .disabled(app.actions.first == id).help("上移")
                                Button("下移", systemImage: "arrow.down") { move(id, by: 1) }
                                    .disabled(app.actions.last == id).help("下移")
                                Button("删除动作", systemImage: "trash", role: .destructive) {
                                    app.actions.removeAll { $0 == id }
                                    save()
                                }
                                .buttonStyle(SettingsButtonStyle(emphasis: .destructive))
                                .help("删除动作")
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(SettingsButtonStyle(emphasis: .quiet))
                            .contentShape(.rect)
                            .background(dropTarget == id ? Color.blue.opacity(0.08) : .clear, in: .rect(cornerRadius: 8))
                            .draggable(id)
                            .dropDestination(for: String.self) { identifiers, _ in
                                guard identifiers.count == 1,
                                      let source = app.actions.firstIndex(of: identifiers[0]),
                                      let destination = app.actions.firstIndex(of: id), source != destination else { return false }
                                app.actions.move(fromOffsets: IndexSet(integer: source), toOffset: destination > source ? destination + 1 : destination)
                                save()
                                return true
                            } isTargeted: { targeted in
                                dropTarget = targeted ? id : nil
                            }
                        }
                    }
                    Divider().opacity(0.5)
                    HStack {
                        OnePicker(exceptActions: $app.actions) { id in
                            app.actions.append(id)
                            save()
                        }
                        Spacer()
                        if app.bundleID != "Default" {
                            Button("移除应用配置", systemImage: "trash", role: .destructive, action: removeApplication)
                                .buttonStyle(SettingsButtonStyle(emphasis: .destructive))
                        }
                    }
                }.padding(.top, 12)
            } label: {
                HStack(spacing: 12) {
                    getIcon(app.bundleID)
                        .frame(width: 36, height: 36)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getAppName(app.bundleID)).font(.subheadline.weight(.semibold))
                        if app.bundleID == "Default" {
                            Text("应用未单独配置时使用").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text(app.bundleID).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("\(app.actions.count) 个动作")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .contextMenu {
                    if app.bundleID != "Default" {
                        Button("Delete", role: .destructive, action: removeApplication)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
    }

    private func save() {
        if app.bundleID == "Default" { cfg.defaultActions = app.actions }
        ConfigurationManager.shared.userConfiguration = cfg
        ConfigurationManager.shared.saveConfiguration()
    }

    private func move(_ id: ActionID, by offset: Int) {
        guard let index = app.actions.firstIndex(of: id) else { return }
        app.actions.swapAt(index, index + offset)
        save()
    }

    private func removeApplication() {
        cfg.appConditions.removeAll { $0.bundleID == app.bundleID }
        ConfigurationManager.shared.userConfiguration = cfg
        ConfigurationManager.shared.saveConfiguration()
    }

    private func getAppName(_ bundleID: String) -> String {
        if bundleID == "Default" { return String(localized: "Default Actions") }
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
        return FileManager.default.displayName(atPath: bundleURL.path)
    }

    @ViewBuilder private func getIcon(_ bundleID: String) -> some View {
        if bundleID == "Default" {
            Image(systemName: "app.gift").font(.title2).foregroundStyle(.blue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.blue.opacity(0.10), in: .rect(cornerRadius: 9))
        } else {
            let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
            Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path))
                .resizable().scaledToFit()
        }
    }
}

struct Application: Identifiable {
    let id: String
    let icon: Image
    let localizedName: String
    var isRunning: Bool
}

struct OnePicker: View {
    @Binding var exceptActions: [ActionID]
    let onChange: (String) -> Void

    var body: some View {
        Menu {
            ForEach(GetAllActions().filter { !exceptActions.contains($0.actionMeta.identifier) }, id: \.actionMeta.identifier) { action in
                Button(action.actionMeta.title) { onChange(action.actionMeta.identifier) }
            }
        } label: {
            Label("添加动作", systemImage: "plus")
                .font(.subheadline.weight(.medium)).foregroundStyle(.blue)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(.blue.opacity(0.10), in: .rect(cornerRadius: 9))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    }
}

#Preview {
    ApplicationActionListView()
}
