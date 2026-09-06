import AppKit
import Foundation
import Testing
import Yams
@testable import Selected

struct PluginCapabilitiesTests {
    @Test func requiredFieldsKeepConfigurationAccessibleAndBlockActions() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        var plugin = Plugin.new()
        plugin.info.options = [Option(identifier: "endpoint", type: .string, required: true), Option(identifier: "optional_token", type: .secret)]
        defer { UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName(plugin.id)) }
        try workspace.manager.save(plugin, replacing: nil)
        #expect(workspace.manager.plugins.count == 1)
        #expect(workspace.manager.loadIssues.isEmpty)
        #expect(plugin.info.missingOptions().map(\.identifier) == ["endpoint"])
        #expect(!workspace.manager.allActions.contains { $0.actionMeta.identifier == plugin.actions[0].meta.identifier })
        try plugin.info.options[0].save("https://example.com", pluginID: plugin.id)
        #expect(plugin.info.missingOptions().isEmpty)
        #expect(workspace.manager.allActions.contains { $0.actionMeta.identifier == plugin.actions[0].meta.identifier })
    }

    @Test func brokenPluginCanBeRepairedWithoutLosingResources() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        let plugin = Plugin.new()
        try workspace.manager.save(plugin, replacing: nil)
        let installed = try #require(workspace.manager.plugins.first)
        let directory = workspace.manager.directory(for: installed)
        let invalid = Data("info: [".utf8)
        try invalid.write(to: directory.appendingPathComponent("config.yaml"))
        try Data("asset".utf8).write(to: directory.appendingPathComponent("asset.txt"))
        workspace.manager.loadPlugins()
        let issue = try #require(workspace.manager.loadIssues.first)
        #expect(throws: (any Error).self) { try workspace.manager.repair("still: [", issue: issue, original: invalid) }
        let id = try workspace.manager.repair(YAMLEncoder().encode(plugin), issue: issue, original: invalid)
        #expect(id == plugin.id)
        #expect(workspace.manager.loadIssues.isEmpty)
        #expect(try String(contentsOf: directory.appendingPathComponent("asset.txt"), encoding: .utf8) == "asset")
        #expect(throws: PluginValidationError.self) { try workspace.manager.repair(YAMLEncoder().encode(plugin), issue: issue, original: invalid) }
    }

    @Test @MainActor func trialPreviewUsesNativePromptAndURLSemantics() throws {
        var plugin = Plugin.new()
        var action = Action.new(kind: .gpt)
        action.gpt?.prompt = "{{ options.language }}: {{ selected.text }}"
        let context = SelectedTextContext(Text: "你好 & hello")
        #expect(try PluginTrial.preview(action, plugin: plugin, context: context, values: ["language": "English"]) == "English: 你好 & hello")
        action = Action.new(kind: .url)
        action.meta.regex = "hello"
        #expect(try action.prepareContext(context, options: [:]).Text == context.Text)
        let preview = try PluginTrial.preview(action, plugin: plugin, context: context, values: [:])
        #expect(URLComponents(string: preview)?.queryItems?.first?.value == context.Text)
        plugin.info.options = [Option(identifier: "token", type: .secret, required: true)]
        #expect(throws: PluginValidationError.self) { try PluginTrial.preview(action, plugin: plugin, context: context, values: [:]) }
    }

    @Test func redactsSecretsAndEncodedSecrets() {
        let redactor = PluginRedactor(secrets: ["secret&123", "", "other-token"])
        #expect(redactor.redact("secret&123 secret%26123 other-token") == "•••• •••• ••••")
    }

    @Test func commandDiagnosticsAreAvailableOnSuccessAndFailure() throws {
        let result = try executeCommandResult(workdir: NSTemporaryDirectory(), command: "/bin/sh", arguments: ["-c", "printf partial; printf diagnostic >&2; exit 3"], withEnv: [:])
        #expect(result.output == "partial")
        #expect(result.diagnostics == "diagnostic")
        #expect(result.exitCode == 3)
    }

    @Test func commandCanBeCancelled() async throws {
        let cancellation = CommandCancellation()
        let task = Task.detached {
            try executeCommandResult(workdir: NSTemporaryDirectory(), command: "/bin/sleep", arguments: ["20"], withEnv: [:], cancellation: cancellation)
        }
        try await Task.sleep(for: .milliseconds(100))
        cancellation.cancel()
        do {
            _ = try await task.value
            Issue.record("Cancelled command must throw")
        } catch is CancellationError { }
    }
}

struct PopClipImporterTests {
    @Test func importsAliasesOptionsAndActionDefaults() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        let package = try package(in: workspace, source: """
        Extension Name: Example
        Extension Identifier: test.example
        Image File: symbol:link
        URL: https://example.com?q=***&enabled={popclip option enabled}
        Required Apps: [com.apple.Safari]
        Options:
          - Option Identifier: enabled
            Type: boolean
        Actions:
          - Title: Search
          - Title: Search More
            URL: https://example.net?q={popclip text}
        """)
        let imported = try PopClipImporter.inspect(package)
        #expect(imported.issues.isEmpty)
        let plugin = try #require(imported.plugin)
        #expect(plugin.info.options[0].defaultVal == "true")
        #expect(plugin.actions.count == 2)
        #expect(plugin.actions[0].meta.requiredApps == ["com.apple.Safari"])
        #expect(plugin.actions[0].url?.url == "https://example.com?q={selected.text}&enabled={selected.options.enabled}")
        let values = PopClipAction.optionValues(plugin.info, values: ["enabled": "true"])
        #expect(values["enabled"] == "1")
        #expect(plugin.info.version == "1.0.0")
        try workspace.manager.save(plugin, replacing: nil, resources: imported.directory)
        let installed = try #require(workspace.manager.plugins.first)
        #expect(installed.importedFrom == package.lastPathComponent)
        let original = workspace.manager.directory(for: installed).appendingPathComponent("PopClip Source/Example.popclipext/Config.yaml")
        #expect(FileManager.default.fileExists(atPath: original.path))
        #expect(workspace.manager.allActions.contains { $0.actionMeta.identifier == plugin.actions[0].meta.identifier })
        #expect(!FilterActions(SelectedTextContext(Text: "hello", BundleID: "elsewhere"), list: workspace.manager.allActions).contains { $0.actionMeta.identifier == plugin.actions[0].meta.identifier })
    }

    @Test func popClipFilteringNarrowsInputWithoutChangingNativeRules() throws {
        var adapter = PopClipAction()
        adapter.requirements = ["url"]
        adapter.regex = #"(?<=://)[^/]+"#
        let input = SelectedTextContext(Text: "链接：https://example.org/docs")
        #expect(try adapter.prepare(input, options: [:]).Text == "example.org")
        adapter.regex = nil
        #expect(try adapter.prepare(SelectedTextContext(Text: "go to apple.com"), options: [:]).Text == "https://apple.com")
        adapter.requirements = ["isurl"]
        #expect(throws: PluginValidationError.self) { try adapter.prepare(input, options: [:]) }
        adapter.requirements = ["option-enabled=1", "!paste"]
        #expect(try adapter.prepare(input, options: ["enabled": "1"]).Text == input.Text)
    }

    @Test func popClipURLTrimsAndCleansBeforeEncoding() {
        var adapter = PopClipAction()
        adapter.cleanQuery = true
        adapter.spacesAsPlus = true
        let url = adapter.renderURL("https://example.com?q={selected.text}", context: SelectedTextContext(Text: "  中文\n\t a&b  "), options: [:])
        #expect(url == "https://example.com?q=%E4%B8%AD%E6%96%87+a%26b")
        #expect(adapter.renderURL("https://example.com/a%20b?static=c%20d&q={selected.text}", context: SelectedTextContext(Text: "a b"), options: [:]) == "https://example.com/a%20b?static=c%20d&q=a+b")
        #expect(adapter.renderURL("https://example.com?q={selected.text}", context: SelectedTextContext(Text: "hello"), options: [:], exactPhrase: true).contains("%22hello%22"))
    }

    @Test(arguments: ["javascript: popclip.copyText('test')", "shell script: echo test", "capture html: true\nservice name: Make Sticky", "submenu: []", "url: https://example.com\nunknown: true", "key combo: cmd b\nkey combo target: app"])
    func unsupportedCapabilitiesNeverPartiallyInstall(_ fields: String) throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        let imported = try PopClipImporter.inspect(package(in: workspace, source: "name: Unsupported\n" + fields))
        #expect(imported.plugin == nil)
        #expect(!imported.issues.isEmpty)
        #expect(workspace.manager.plugins.isEmpty)
    }

    @Test func readsJSONAndPlistPackages() throws {
        for name in ["Config.json", "Config.plist"] {
            let workspace = try PluginTestWorkspace()
            defer { workspace.cleanUp() }
            let package = workspace.root.appendingPathComponent("Example.popclipext")
            try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
            let config: [String: Any] = ["name": ["en": "Example", "zh-hans": "示例"], "keyCombo": "command B"]
            let data = name.hasSuffix("json") ? try JSONSerialization.data(withJSONObject: config) : try PropertyListSerialization.data(fromPropertyList: config, format: .xml, options: 0)
            try data.write(to: package.appendingPathComponent(name))
            let result = try PopClipImporter.inspect(package)
            #expect(result.issues.isEmpty)
            #expect(result.plugin?.actions.first?.keycombo?.keycombo == "cmd b")
        }
    }

    @Test func importsZippedPackagesAndRejectsSymbolicLinks() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        let package = try package(in: workspace, source: "name: Example\nservice name: Make Sticky")
        let archive = workspace.root.appendingPathComponent("Example.popclipextz")
        _ = try executeCommand(workdir: workspace.root.path, command: "/usr/bin/ditto", arguments: ["-c", "-k", "--keepParent", package.path, archive.path], withEnv: [:])
        let imported = try PopClipImporter.inspect(archive)
        #expect(imported.issues.isEmpty)
        #expect(imported.plugin?.actions.first?.service?.name == "Make Sticky")
        try FileManager.default.createSymbolicLink(at: package.appendingPathComponent("external"), withDestinationURL: workspace.root)
        let rejected = try PopClipImporter.inspect(package)
        #expect(rejected.plugin == nil)
        #expect(!rejected.issues.isEmpty)
    }

    @Test func rejectsArchiveTraversalBeforeExtracting() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        let archive = workspace.root.appendingPathComponent("Traversal.popclipextz")
        let data = try #require(Data(base64Encoded: "UEsDBBQAAAAAAGJqJl1bAbieDwAAAA8AAAAOAAAALi4vZXNjYXBlZC50eHRtdXN0IG5vdCBlc2NhcGVQSwMEFAAAAAAAYmomXd9YV64mAAAAJgAAAB4AAABFeGFtcGxlLnBvcGNsaXBleHQvQ29uZmlnLnlhbWxuYW1lOiBFeGFtcGxlCnVybDogaHR0cHM6Ly9leGFtcGxlLmNvbVBLAQIUAxQAAAAAAGJqJl1bAbieDwAAAA8AAAAOAAAAAAAAAAAAAACAAQAAAAAuLi9lc2NhcGVkLnR4dFBLAQIUAxQAAAAAAGJqJl3fWFeuJgAAACYAAAAeAAAAAAAAAAAAAACAATsAAABFeGFtcGxlLnBvcGNsaXBleHQvQ29uZmlnLnlhbWxQSwUGAAAAAAIAAgCIAAAAnQAAAAAA"))
        try data.write(to: archive)
        let result = try PopClipImporter.inspect(archive)
        #expect(result.plugin == nil)
        #expect(!result.issues.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: result.directory.appendingPathComponent("escaped.txt").path))
    }

    @Test func importedUpdatesKeepSettingsAndOriginalSourceForRollback() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        let originalSource = "name: Example\nidentifier: test.update\nurl: https://example.com?q=***"
        let sourcePackage = try package(in: workspace, source: originalSource)
        let first = try PopClipImporter.inspect(sourcePackage)
        let plugin = try #require(first.plugin)
        let option = Option(identifier: "language", type: .string)
        defer { UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName(plugin.id)) }
        try option.save("中文", pluginID: plugin.id)
        try workspace.manager.save(plugin, replacing: nil, resources: first.directory)
        let installed = try #require(workspace.manager.plugins.first)
        try "name: Renamed\nidentifier: test.update\nurl: https://example.net?q=***".write(to: sourcePackage.appendingPathComponent("Config.yaml"), atomically: true, encoding: .utf8)
        let second = try PopClipImporter.inspect(sourcePackage)
        var update = try #require(second.plugin)
        #expect(update.id == plugin.id)
        update.info.version = "1.0.1"
        try workspace.manager.save(update, replacing: installed, resources: second.directory)
        let updated = try #require(workspace.manager.plugins.first)
        #expect(updated.info.name == "Renamed")
        #expect(option.value(pluginID: plugin.id) == "中文")
        try workspace.manager.restorePreviousVersion(updated)
        let restored = try #require(workspace.manager.plugins.first)
        let source = workspace.manager.directory(for: restored).appendingPathComponent("PopClip Source/Example.popclipext/Config.yaml")
        #expect(try String(contentsOf: source, encoding: .utf8) == originalSource)
    }

    @Test func supportsCommonNamedKeysAndRejectsInvalidDefaults() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        let package = try package(in: workspace, source: "name: Keys\nkey combos: [command space, option left, f12]")
        let imported = try PopClipImporter.inspect(package)
        #expect(imported.issues.isEmpty)
        #expect(imported.plugin?.actions.first?.keycombo?.keycombos == ["cmd space", "option left", "f12"])
        try "name: Bad\nurl: https://example.com\noptions: [{identifier: enabled, type: boolean, default value: 1.5}]".write(to: package.appendingPathComponent("Config.yaml"), atomically: true, encoding: .utf8)
        #expect(try PopClipImporter.inspect(package).plugin == nil)
    }

    private func package(in workspace: PluginTestWorkspace, source: String) throws -> URL {
        let directory = workspace.root.appendingPathComponent("Example.popclipext")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try source.write(to: directory.appendingPathComponent("Config.yaml"), atomically: true, encoding: .utf8)
        return directory
    }
}
