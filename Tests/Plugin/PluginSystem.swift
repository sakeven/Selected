import Foundation
import Testing
import Yams
@testable import Selected

struct PluginSystemTests {
    @Test func commandOutputDoesNotIncludeDiagnosticsAndFailuresThrow() throws {
        let output = try executeCommand(workdir: NSTemporaryDirectory(), command: "/bin/sh",
                                        arguments: ["-c", "printf result; printf diagnostic >&2"], withEnv: [:])
        #expect(output == "result")
        #expect(throws: (any Error).self) {
            try executeCommand(workdir: NSTemporaryDirectory(), command: "selected-missing-" + UUID().uuidString, withEnv: [:])
        }
        #expect(throws: (any Error).self) {
            try executeCommand(workdir: NSTemporaryDirectory(), command: "/bin/sh",
                               arguments: ["-c", "printf partial; printf failed >&2; exit 3"], withEnv: [:])
        }
    }

    @Test func nativeBooleanDefaultsDecode() throws {
        let option = try YAMLDecoder().decode(Option.self, from: "identifier: enabled\ntype: boolean\ndefaultVal: true")
        #expect(option.defaultValue == "true")
    }

    @Test func sameVersionExternalEditsAreNotOverwritten() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        try workspace.manager.save(.new(), replacing: nil)
        let installed = try #require(workspace.manager.plugins.first)
        var external = try workspace.manager.manifest(for: installed)
        external.actions[0].meta.title = "Edited in another editor"
        try workspace.write(external, to: workspace.manager.directory(for: installed))
        var draft = installed
        draft.info.version = "1.0.1"
        #expect(throws: PluginValidationError.self) { try workspace.manager.save(draft, replacing: installed) }
        #expect(try workspace.manager.manifest(for: installed).actions[0].meta.title == "Edited in another editor")
    }

    @Test(arguments: ["", " ", "\n"])
    func emptySecretDefaultsKeepPluginConfigurable(_ emptyValue: String) throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        var plugin = Plugin.new()
        plugin.info.name = "AIChat"
        plugin.info.options = [Option(identifier: "search_token", type: .secret, defaultVal: emptyValue)]
        let package = try workspace.package(plugin)
        try workspace.manager.install(url: package)
        let installed = try #require(workspace.manager.plugins.first)
        #expect(workspace.manager.loadIssues.isEmpty)
        #expect(installed.info.options.first?.identifier == "search_token")
        #expect(installed.info.options.first?.type == .secret)
        #expect(installed.info.options.first?.defaultValue == "")
    }

    @Test func semanticVersions() throws {
        let ordered = ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0", "1.2.0", "1.10.0", "2.0.0"]
        let versions = try ordered.map { try #require(PluginVersion($0)) }
        #expect(versions.sorted() == versions)
        #expect(PluginVersion("1.2") == PluginVersion("1.2.0+build.7"))
        #expect(PluginVersion("1.2.3")?.nextPatch == "1.2.4")
    }

    @Test(arguments: ["", "v1.2.3", "1..2", "01.0.0", "1.0.0-01", "1.0.0-", "1.0.0+", "1.0.0.0", "-1.0.0"])
    func rejectsInvalidVersions(_ value: String) {
        #expect(PluginVersion(value) == nil)
    }

    @Test func rejectsAmbiguousActionsAndInvalidSchema() {
        var plugin = Plugin.new()
        plugin.actions[0].gpt = GptAction(prompt: "Hello")
        #expect(throws: PluginValidationError.self) { try plugin.validate() }
        plugin.actions[0].gpt = nil
        plugin.schemaVersion = 2
        #expect(throws: PluginValidationError.self) { try plugin.validate() }
    }

    @Test func rejectsBrokenRegexDuplicateIDsAndOptions() {
        var plugin = Plugin.new()
        plugin.actions[0].meta.regex = "["
        #expect(throws: PluginValidationError.self) { try plugin.validate() }
        plugin.actions[0].meta.regex = nil
        plugin.actions.append(plugin.actions[0])
        #expect(throws: PluginValidationError.self) { try plugin.validate() }
        plugin.actions.removeLast()
        plugin.info.options = [Option(identifier: "token", type: .secret, defaultVal: "must-not-be-in-a-package")]
        #expect(throws: PluginValidationError.self) { try plugin.validate() }
        plugin.info.options = [Option(identifier: "choice", type: .multiple)]
        #expect(throws: PluginValidationError.self) { try plugin.validate() }
        plugin.info.options = [Option(identifier: "choice", type: .multiple, defaultVal: "missing", values: ["a", "b"])]
        #expect(throws: PluginValidationError.self) { try plugin.validate() }
        plugin.info.options = [Option(identifier: "token", type: .string), Option(identifier: "TOKEN", type: .string)]
        #expect(throws: PluginValidationError.self) { try plugin.validate() }
    }

    @Test func optionDefaultsAndExplicitFalse() throws {
        let pluginID = "test.options." + UUID().uuidString
        defer { UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName(pluginID)) }
        let enabled = Option(identifier: "enabled", type: .boolean, defaultVal: "true")
        #expect(enabled.value(pluginID: pluginID) == "true")
        try enabled.save("false", pluginID: pluginID)
        #expect(enabled.value(pluginID: pluginID) == "false")
        let choice = Option(identifier: "choice", type: .multiple, values: ["first", "second"])
        #expect(choice.value(pluginID: pluginID) == "first")
        try choice.save("retired", pluginID: pluginID)
        #expect(choice.value(pluginID: pluginID) == "first")
    }

    @Test func urlTemplatesEncodeDataWithoutRecursion() throws {
        let text = "中文 &x=1#fragment {selected.options.token}"
        let url = PluginTemplate.render("https://example.com/?q={selected.text}&mode={selected.options.mode}",
                                        context: SelectedTextContext(Text: text), options: ["mode": "a&b", "token": "secret"], urlEncoded: true)
        let query = try #require(URLComponents(string: url)?.queryItems)
        #expect(query.first?.value == text)
        #expect(query.last?.value == "a&b")
        #expect(!url.contains("secret"))
        #expect(PluginTemplate.render("{text}", context: SelectedTextContext(Text: "hello"), options: [:]) == "hello")
    }

    @Test func commonFiltersAndLegacySupported() {
        var meta = GenericAction(title: "Action", icon: "symbol:bolt", identifier: "test.action")
        meta.requirements = [.text, .editable, .url]
        meta.requiredApps = ["test.editor"]
        var context = SelectedTextContext(Text: "a link", BundleID: "test.editor", URLs: ["https://example.com"], Editable: true)
        #expect(meta.matches(context))
        context.Editable = false
        #expect(!meta.matches(context))
        context.Editable = true
        meta.excludedApps = ["test.editor"]
        #expect(!meta.matches(context))
        let supported = Supported(urls: ["example.com"])
        #expect(!supported.match(url: "", bundleID: "test.editor"))
        #expect(!supported.match(url: "https://elsewhere.com", bundleID: "test.editor"))
        #expect(supported.match(url: "https://example.com", bundleID: "test.editor"))
    }

    @Test func roundTripRetainsActionsOptionsAndResources() throws {
        let yaml = """
        schemaVersion: 1
        info:
          identifier: test.roundtrip
          name: Example
          icon: file://./icon.svg
          version: 1.2.3
          enabled: false
          options:
            - identifier: verbose
              type: boolean
              defaultVal: 'true'
              label: Verbose output
        actions:
          - meta:
              title: AI
              icon: symbol:sparkles
              identifier: test.roundtrip.ai
              after: copy
              requirements: [text]
            gpt:
              prompt: '{{selected.text}}'
              reasoning: true
              tools:
                - name: lookup
                  description: Lookup
                  parameters: '{"type":"object","properties":{}}'
                  command: [./lookup.sh]
          - meta:
              title: Keys
              icon: symbol:keyboard
              identifier: test.roundtrip.keys
            keycombo:
              keycombos: [cmd c, cmd v]
              supported:
                apps: [{bundleID: test.editor}]
        """
        let plugin = try YAMLDecoder().decode(Plugin.self, from: yaml)
        try plugin.validate()
        let encoded = try YAMLEncoder().encode(plugin)
        let decoded = try YAMLDecoder().decode(Plugin.self, from: encoded)
        #expect(decoded.info.enabled == false)
        #expect(decoded.info.icon == "file://./icon.svg")
        #expect(decoded.info.options[0].label == "Verbose output")
        #expect(decoded.actions[0].gpt?.tools?.first?.command == ["./lookup.sh"])
        #expect(decoded.actions[1].keycombo?.keycombos == ["cmd c", "cmd v"])
        #expect(!encoded.contains("pluginDir"))
        #expect(!encoded.contains("pluginPath"))
        var draft = decoded
        draft.actions[0].gpt?.prompt = "Changed"
        #expect(decoded.actions[0].gpt?.prompt == "{{selected.text}}")
    }

    @Test func installUpgradeRollbackAndKeepSettings() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        var plugin = Plugin.new()
        let package = try workspace.package(plugin)
        try "v1 asset".write(to: package.appendingPathComponent("asset.txt"), atomically: true, encoding: .utf8)
        try workspace.manager.install(url: package)
        let installed = try #require(workspace.manager.plugins.first)
        workspace.manager.setEnabled(false, for: installed)
        let option = Option(identifier: "language", type: .string)
        try option.save("中文", pluginID: installed.id)
        defer { UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName(installed.id)) }
        plugin.info.version = "1.1.0"
        plugin.info.name = "Renamed plugin"
        try workspace.write(plugin, to: package)
        try "v2 asset".write(to: package.appendingPathComponent("asset.txt"), atomically: true, encoding: .utf8)
        try workspace.manager.install(url: package)
        let updated = try #require(workspace.manager.plugins.first)
        #expect(workspace.manager.plugins.count == 1)
        #expect(updated.info.name == "Renamed plugin")
        #expect(!updated.info.enabled)
        #expect(option.value(pluginID: updated.id) == "中文")
        #expect(workspace.manager.hasPreviousVersion(updated))
        #expect(throws: PluginValidationError.self) { try workspace.manager.install(url: package) }
        try workspace.manager.restorePreviousVersion(updated)
        let restored = try #require(workspace.manager.plugins.first)
        #expect(restored.info.version == "1.0.0")
        #expect(!restored.info.enabled)
        #expect(try String(contentsOf: workspace.manager.directory(for: restored).appendingPathComponent("asset.txt"), encoding: .utf8) == "v1 asset")
    }

    @Test func invalidUpdateLeavesInstalledPackageUntouched() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        let plugin = Plugin.new()
        let package = try workspace.package(plugin)
        try workspace.manager.install(url: package)
        try "invalid: [".write(to: package.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        #expect(throws: (any Error).self) { try workspace.manager.install(url: package) }
        workspace.manager.loadPlugins()
        #expect(workspace.manager.plugins.first?.info.version == "1.0.0")
        #expect(workspace.manager.loadIssues.isEmpty)
    }

    @Test func brokenPluginsAreIsolatedAndIncompatibleOnesDoNotRun() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        var plugin = Plugin.new()
        plugin.info.minSelectedVersion = "99.0.0"
        let package = try workspace.package(plugin)
        #expect(throws: PluginValidationError.self) { try workspace.manager.install(url: package) }
        try FileManager.default.copyItem(at: package, to: workspace.manager.extensionsDir.appendingPathComponent("future.selectedext"))
        let broken = workspace.manager.extensionsDir.appendingPathComponent("broken.selectedext")
        try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
        try "info: [".write(to: broken.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        workspace.manager.loadPlugins()
        #expect(workspace.manager.plugins.count == 1)
        #expect(workspace.manager.loadIssues.count == 1)
        #expect(!workspace.manager.allActions.contains { $0.actionMeta.identifier == plugin.actions[0].meta.identifier })
    }

    @Test func visualSavePreservesFilesAndRejectsCollisions() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        let plugin = Plugin.new()
        let package = try workspace.package(plugin)
        try "resource".write(to: package.appendingPathComponent("icon.svg"), atomically: true, encoding: .utf8)
        try workspace.manager.install(url: package)
        let existing = try #require(workspace.manager.plugins.first)
        var draft = try workspace.manager.manifest(for: existing)
        draft.info.version = "1.0.1"
        draft.actions[0].meta.title = "Edited"
        try workspace.manager.save(draft, replacing: existing)
        let updated = try #require(workspace.manager.plugins.first)
        #expect(updated.actions[0].meta.title == "Edited")
        #expect(try String(contentsOf: workspace.manager.directory(for: updated).appendingPathComponent("icon.svg"), encoding: .utf8) == "resource")
        var conflict = Plugin.new()
        conflict.actions[0].meta.identifier = draft.actions[0].meta.identifier
        #expect(throws: PluginValidationError.self) { try workspace.manager.save(conflict, replacing: nil) }
        let export = workspace.root.appendingPathComponent("export.selectedext")
        try workspace.manager.export(updated, to: export)
        #expect(try workspace.manager.readManifest(at: export).info.version == "1.0.1")
    }
}

struct PluginTestWorkspace {
    let root: URL
    let manager: PluginManager
    let suiteName: String

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("Selected-PluginTests-" + UUID().uuidString, isDirectory: true)
        suiteName = "Selected.PluginTests." + UUID().uuidString
        manager = PluginManager(extensionsDir: root.appendingPathComponent("Extensions", isDirectory: true), hostVersion: "0.2.5", defaults: UserDefaults(suiteName: suiteName)!)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func package(_ plugin: Plugin) throws -> URL {
        let directory = root.appendingPathComponent(UUID().uuidString + ".selectedext", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try write(plugin, to: directory)
        return directory
    }

    func write(_ plugin: Plugin, to directory: URL) throws {
        try YAMLEncoder().encode(plugin).write(to: directory.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}
