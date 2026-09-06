import Foundation
import SwiftUI
import Yams

class PluginManager: ObservableObject {
    let extensionsDir: URL
    let hostVersion: String
    private let fileManager = FileManager.default
    private let defaults: UserDefaults

    @Published private(set) var plugins: [Plugin] = []
    @Published private(set) var loadIssues: [String] = []
    @Published var optionValueChangeCnt = 0

    static let shared = PluginManager()

    init(extensionsDir: URL = appSupportURL.appendingPathComponent("Extensions", isDirectory: true),
         hostVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
         defaults: UserDefaults = .standard) {
        self.extensionsDir = extensionsDir
        self.hostVersion = hostVersion
        self.defaults = defaults
    }

    func readManifest(at directory: URL) throws -> Plugin {
        let data = try Data(contentsOf: directory.appendingPathComponent("config.yaml"))
        var plugin = try YAMLDecoder().decode(Plugin.self, from: data)
        plugin.source = data
        try plugin.validate()
        return plugin
    }

    func manifest(for plugin: Plugin) throws -> Plugin {
        try readManifest(at: directory(for: plugin))
    }

    func directory(for plugin: Plugin) -> URL {
        extensionsDir.appendingPathComponent(plugin.info.pluginDir, isDirectory: true)
    }

    private func previousDirectory(for plugin: Plugin) -> URL {
        extensionsDir.appendingPathComponent(".previous-" + plugin.info.pluginDir, isDirectory: true)
    }

    func hasPreviousVersion(_ plugin: Plugin) -> Bool {
        fileManager.fileExists(atPath: previousDirectory(for: plugin).appendingPathComponent("config.yaml").path)
    }

    func setEnabled(_ enabled: Bool, for plugin: Plugin) {
        defaults.set(enabled, forKey: "plugin.enabled." + plugin.id)
        if let index = plugins.firstIndex(where: { $0.id == plugin.id }) {
            plugins[index].info.enabled = enabled
        }
    }

    private func checkConflicts(_ plugin: Plugin, replacing existing: Plugin?) throws {
        let others = plugins.filter { $0.id != existing?.id }
        if others.contains(where: { $0.id == plugin.id }) {
            throw PluginValidationError(messages: ["插件标识已存在：\(plugin.id)。"])
        }
        let actionIDs = Set(others.flatMap { $0.actions.map(\.meta.identifier) })
        let conflicts = plugin.actions.filter { actionIDs.contains($0.meta.identifier) }
        if !conflicts.isEmpty {
            throw PluginValidationError(messages: conflicts.map { "动作标识已被其他插件使用：\($0.meta.identifier)。" })
        }
    }

    private func checkUpgrade(_ plugin: Plugin, from existing: Plugin?) throws {
        guard let existing else { return }
        guard plugin.id == existing.id else {
            throw PluginValidationError(messages: ["已安装插件的标识不可更改。"])
        }
        if let old = existing.info.version.flatMap(PluginVersion.init) {
            guard let new = plugin.info.version.flatMap(PluginVersion.init), new > old else {
                throw PluginValidationError(messages: ["新版本必须高于已安装版本 \(existing.info.version ?? "")。"])
            }
        }
    }

    func install(url: URL) throws {
        loadPlugins()
        let incoming = try readManifest(at: url)
        if let issue = incoming.compatibilityIssue(hostVersion: hostVersion) {
            throw PluginValidationError(messages: [issue])
        }
        let existing = plugins.first { $0.id == incoming.id }
        try checkConflicts(incoming, replacing: existing)
        try checkUpgrade(incoming, from: existing)
        let destination = existing.map(directory(for:)) ?? extensionsDir.appendingPathComponent(url.lastPathComponent, isDirectory: true)
        if existing == nil, fileManager.fileExists(atPath: destination.path) {
            throw PluginValidationError(messages: ["安装目录已被其他插件占用：\(destination.lastPathComponent)。"])
        }
        try stageAndReplace(source: url, manifest: nil, destination: destination)
        loadPlugins()
    }

    func save(_ plugin: Plugin, replacing existing: Plugin?) throws {
        try plugin.validate()
        if let issue = plugin.compatibilityIssue(hostVersion: hostVersion) {
            throw PluginValidationError(messages: [issue])
        }
        loadPlugins()
        let current: Plugin?
        if let existing {
            guard let installed = plugins.first(where: { $0.id == existing.id }),
                  installed.source == existing.source else {
                throw PluginValidationError(messages: ["插件已在编辑期间发生变化，请重新打开编辑器。"])
            }
            current = installed
        } else {
            guard plugin.info.identifier != nil, plugin.info.version != nil else {
                throw PluginValidationError(messages: ["新插件必须填写标识和版本。"])
            }
            current = nil
        }
        try checkConflicts(plugin, replacing: current)
        try checkUpgrade(plugin, from: current)
        let destination = current.map(directory(for:)) ?? extensionsDir.appendingPathComponent(plugin.id + ".selectedext", isDirectory: true)
        if current == nil, fileManager.fileExists(atPath: destination.path) {
            throw PluginValidationError(messages: ["安装目录已存在。"])
        }
        let yaml = try YAMLEncoder().encode(plugin)
        try stageAndReplace(source: current.map(directory(for:)), manifest: yaml, destination: destination)
        loadPlugins()
    }

    private func stageAndReplace(source: URL?, manifest: String?, destination: URL) throws {
        try fileManager.createDirectory(at: extensionsDir, withIntermediateDirectories: true)
        let staged = extensionsDir.appendingPathComponent(".staging-" + UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: staged) }
        if let source {
            try fileManager.copyItem(at: source, to: staged)
        } else {
            try fileManager.createDirectory(at: staged, withIntermediateDirectories: false)
        }
        if let manifest {
            try manifest.write(to: staged.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        }
        _ = try readManifest(at: staged)
        if fileManager.fileExists(atPath: destination.path) {
            let backupName = ".previous-" + destination.lastPathComponent
            let backup = extensionsDir.appendingPathComponent(backupName)
            if fileManager.fileExists(atPath: backup.path) { try fileManager.removeItem(at: backup) }
            _ = try fileManager.replaceItemAt(destination, withItemAt: staged, backupItemName: backupName,
                                             options: .withoutDeletingBackupItem)
        } else {
            try fileManager.moveItem(at: staged, to: destination)
        }
    }

    func restorePreviousVersion(_ plugin: Plugin) throws {
        let previous = previousDirectory(for: plugin)
        let restored = try readManifest(at: previous)
        guard restored.id == plugin.id else { throw PluginValidationError(messages: ["历史版本的插件标识不一致。"]) }
        if let issue = restored.compatibilityIssue(hostVersion: hostVersion) { throw PluginValidationError(messages: [issue]) }
        try checkConflicts(restored, replacing: plugin)
        _ = try fileManager.replaceItemAt(directory(for: plugin), withItemAt: previous)
        loadPlugins()
    }

    func remove(_ plugin: Plugin) throws {
        try PluginSecretStore.remove(pluginID: plugin.id)
        try fileManager.removeItem(at: directory(for: plugin))
        if hasPreviousVersion(plugin) { try fileManager.removeItem(at: previousDirectory(for: plugin)) }
        UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName(plugin.id))
        defaults.removeObject(forKey: "plugin.enabled." + plugin.id)
        loadPlugins()
    }

    func export(_ plugin: Plugin, to url: URL) throws {
        try fileManager.copyItem(at: directory(for: plugin), to: url)
    }

    func loadPlugins() {
        var loaded: [Plugin] = []
        var issues: [String] = []
        do {
            try fileManager.createDirectory(at: extensionsDir, withIntermediateDirectories: true)
            let directories = try fileManager.contentsOfDirectory(at: extensionsDir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            var pluginIDs = Set<String>()
            var actionIDs = Plugin.builtInActionIDs
            for directory in directories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                do {
                    guard (try directory.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true else { continue }
                    var plugin = try readManifest(at: directory)
                    guard !pluginIDs.contains(plugin.id) else {
                        throw PluginValidationError(messages: ["重复的插件标识：\(plugin.id)。"])
                    }
                    let ids = Set(plugin.actions.map(\.meta.identifier))
                    guard actionIDs.isDisjoint(with: ids) else {
                        throw PluginValidationError(messages: ["与其他插件的动作标识冲突：\(actionIDs.intersection(ids).sorted().joined(separator: ", "))。"])
                    }
                    pluginIDs.insert(plugin.id)
                    actionIDs.formUnion(ids)
                    plugin.info.pluginDir = directory.lastPathComponent
                    if let enabled = defaults.object(forKey: "plugin.enabled." + plugin.id) as? Bool {
                        plugin.info.enabled = enabled
                    }
                    plugin.info.icon = resolveIcon(plugin.info.icon, in: directory)
                    for index in plugin.actions.indices {
                        plugin.actions[index].meta.icon = resolveIcon(plugin.actions[index].meta.icon, in: directory)
                        plugin.actions[index].runCommand?.pluginPath = directory.path
                        if let tools = plugin.actions[index].gpt?.tools {
                            plugin.actions[index].gpt?.tools = tools.map { tool in
                                var tool = tool
                                tool.workdir = directory.path
                                return tool
                            }
                        }
                    }
                    loaded.append(plugin)
                } catch {
                    issues.append("\(directory.lastPathComponent)：\(error.localizedDescription)")
                }
            }
        } catch { issues.append(error.localizedDescription) }
        plugins = loaded
        loadIssues = issues
    }

    private func resolveIcon(_ icon: String, in directory: URL) -> String {
        icon.hasPrefix("file://./") ? "file://" + directory.appendingPathComponent(String(icon.dropFirst(9))).path : icon
    }

    var allActions: [PerformAction] {
        var result = [WebSearchAction().generate(generic: GenericAction(title: "Search", icon: "symbol:magnifyingglass", identifier: "selected.websearch"))]
        for plugin in plugins where plugin.info.enabled && plugin.compatibilityIssue(hostVersion: hostVersion) == nil {
            for action in plugin.actions {
                var generic = action.meta
                generic.title = PluginTemplate.render(generic.title, context: SelectedTextContext(), options: plugin.info.getOptionsValue())
                let generated: PerformAction?
                switch action.kind {
                case .url: generated = action.url?.generate(pluginInfo: plugin.info, generic: generic)
                case .service: generated = action.service?.generate(generic: generic)
                case .keycombo: generated = action.keycombo?.generate(pluginInfo: plugin.info, generic: generic)
                case .gpt: generated = action.gpt?.generate(pluginInfo: plugin.info, generic: generic)
                case .runCommand: generated = action.runCommand?.generate(pluginInfo: plugin.info, generic: generic)
                }
                if let generated {
                    generated.pluginInfo = plugin.info
                    result.append(generated)
                }
            }
        }
        result.append(TranslationAction(target: "cn").generate(generic: GenericAction(title: "翻译到中文", icon: "square 译中", identifier: "selected.translation.cn")))
        result.append(TranslationAction(target: "en").generate(generic: GenericAction(title: "Translate to English", icon: "symbol:e.square", identifier: "selected.translation.en")))
        result.append(CopyAction().generate(generic: GenericAction(title: "Copy", icon: "symbol:doc.on.clipboard", identifier: "selected.copy")))
        result.append(SpeackAction().generate(generic: GenericAction(title: "Speak", icon: "symbol:play.circle", identifier: "selected.speak")))
        return result
    }
}
