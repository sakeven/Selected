import Foundation
import SwiftUI
import Yams

class PluginManager: ObservableObject {
    let extensionsDir: URL
    let hostVersion: String
    private let fileManager = FileManager.default
    private let defaults: UserDefaults

    @Published private(set) var plugins: [Plugin] = []
    @Published private(set) var loadIssues: [PluginLoadIssue] = []
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
            throw PluginValidationError(messages: [String(localized: "Plugin identifier already exists: \(plugin.id).")])
        }
        let actionIDs = Set(others.flatMap { $0.actions.map(\.meta.identifier) })
        let conflicts = plugin.actions.filter { actionIDs.contains($0.meta.identifier) }
        if !conflicts.isEmpty {
            throw PluginValidationError(messages: conflicts.map { String(localized: "Action identifier is already used by another plugin: \($0.meta.identifier).") })
        }
    }

    private func checkUpgrade(_ plugin: Plugin, from existing: Plugin?) throws {
        guard let existing else { return }
        guard plugin.id == existing.id else {
            throw PluginValidationError(messages: [String(localized: "The identifier of an installed plugin cannot be changed.")])
        }
        if let old = existing.info.version.flatMap(PluginVersion.init) {
            guard let new = plugin.info.version.flatMap(PluginVersion.init), new > old else {
                throw PluginValidationError(messages: [String(localized: "The new version must be higher than the installed version \(existing.info.version ?? "").")])
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
            throw PluginValidationError(messages: [String(localized: "The installation folder is already used by another plugin: \(destination.lastPathComponent).")])
        }
        try stageAndReplace(source: url, manifest: nil, destination: destination)
        loadPlugins()
    }

    func save(_ plugin: Plugin, replacing existing: Plugin?, resources: URL? = nil) throws {
        try plugin.validate()
        if let issue = plugin.compatibilityIssue(hostVersion: hostVersion) {
            throw PluginValidationError(messages: [issue])
        }
        loadPlugins()
        let current: Plugin?
        if let existing {
            guard let installed = plugins.first(where: { $0.id == existing.id }),
                  installed.source == existing.source else {
                throw PluginValidationError(messages: [String(localized: "The plugin changed while you were editing. Please reopen the editor.")])
            }
            current = installed
        } else {
            guard plugin.info.identifier != nil, plugin.info.version != nil else {
                throw PluginValidationError(messages: [String(localized: "New plugins require an identifier and a version.")])
            }
            current = nil
        }
        try checkConflicts(plugin, replacing: current)
        try checkUpgrade(plugin, from: current)
        let destination = current.map(directory(for:)) ?? extensionsDir.appendingPathComponent(plugin.id + ".selectedext", isDirectory: true)
        if current == nil, fileManager.fileExists(atPath: destination.path) {
            throw PluginValidationError(messages: [String(localized: "The installation folder already exists.")])
        }
        let yaml = try YAMLEncoder().encode(plugin)
        try stageAndReplace(source: resources ?? current.map(directory(for:)), manifest: yaml, destination: destination)
        loadPlugins()
    }

    func repair(_ source: String, issue: PluginLoadIssue, original: Data) throws -> String {
        let manifestURL = issue.directory.appendingPathComponent("config.yaml")
        guard try Data(contentsOf: manifestURL) == original else {
            throw PluginValidationError(messages: [String(localized: "The plugin changed while you were editing. Please reopen the editor.")])
        }
        let plugin = try YAMLDecoder().decode(Plugin.self, from: source)
        try plugin.validate()
        loadPlugins()
        try checkConflicts(plugin, replacing: nil)
        try stageAndReplace(source: issue.directory, manifest: source, destination: issue.directory)
        loadPlugins()
        return plugin.id
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
        guard restored.id == plugin.id else { throw PluginValidationError(messages: [String(localized: "The previous version has a different plugin identifier.")]) }
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
        var issues: [PluginLoadIssue] = []
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
                        throw PluginValidationError(messages: [String(localized: "Duplicate plugin identifier: \(plugin.id).")])
                    }
                    let ids = Set(plugin.actions.map(\.meta.identifier))
                    guard actionIDs.isDisjoint(with: ids) else {
                        throw PluginValidationError(messages: [String(localized: "Action identifiers conflict with another plugin: \(actionIDs.intersection(ids).sorted().joined(separator: ", ")).")])
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
                    issues.append(PluginLoadIssue(directory: directory, message: error.localizedDescription))
                }
            }
        } catch { issues.append(PluginLoadIssue(directory: extensionsDir, message: error.localizedDescription)) }
        plugins = loaded
        loadIssues = issues
    }

    private func resolveIcon(_ icon: String, in directory: URL) -> String {
        icon.hasPrefix("file://./") ? "file://" + directory.appendingPathComponent(String(icon.dropFirst(9))).path : icon
    }

    var availablePlugins: [Plugin] {
        plugins.filter { $0.info.enabled && $0.compatibilityIssue(hostVersion: hostVersion) == nil && $0.info.missingOptions().isEmpty }
    }

    var allActions: [PerformAction] {
        var result = [WebSearchAction().generate(generic: GenericAction(title: String(localized: "Search"), icon: "symbol:magnifyingglass", identifier: "selected.websearch"))]
        for plugin in availablePlugins {
            for action in plugin.actions {
                if let generated = action.generate(pluginInfo: plugin.info) {
                    result.append(generated)
                }
            }
        }
        result.append(TranslationAction(target: "cn").generate(generic: GenericAction(title: String(localized: "Translate to Chinese"), icon: "square 译中", identifier: "selected.translation.cn")))
        result.append(TranslationAction(target: "en").generate(generic: GenericAction(title: String(localized: "Translate to English"), icon: "symbol:e.square", identifier: "selected.translation.en")))
        result.append(CopyAction().generate(generic: GenericAction(title: String(localized: "Copy"), icon: "symbol:doc.on.clipboard", identifier: "selected.copy")))
        result.append(SpeackAction().generate(generic: GenericAction(title: String(localized: "Speak"), icon: "symbol:play.circle", identifier: "selected.speak")))
        return result
    }
}
