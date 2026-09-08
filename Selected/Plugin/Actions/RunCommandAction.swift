//
//  ScriptAction.swift
//  Selected
//
//  Created by sake on 2024/3/19.
//

import Foundation
import AppKit


struct RunCommandAction: Codable {
    var command: [String]
    var pluginPath: String? // we will execute command in pluginPath.

    enum CodingKeys: String, CodingKey {
        case command
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        command = try values.decode([String].self, forKey: .command)
    }


    init(command: [String], options: [Option]) {
        self.command = command
    }

    func environment(pluginInfo: PluginInfo, generic: GenericAction, context: SelectedTextContext) -> [String: String] {
        var env = ["SELECTED_TEXT": context.Text,
                   "SELECTED_PLUGIN": pluginInfo.id,
                   "SELECTED_PLUGIN_VERSION": pluginInfo.version ?? "",
                   "SELECTED_EDITABLE": context.Editable.description,
                   "SELECTED_BUNDLEID": context.BundleID,
                   "SELECTED_ACTION": generic.identifier,
                   "SELECTED_WEBPAGE_URL": context.WebPageURL,
                   "SELECTED_URLS": context.URLs.joined(separator: "\n")]
        if generic.includeClipboard == true { env["SELECTED_CLIPBOARD_TEXT"] = context.ClipboardText ?? "" }
        for (key, value) in pluginInfo.getOptionsValue() { env["SELECTED_OPTIONS_" + key.uppercased()] = value }
        return env
    }

    func generate(pluginInfo: PluginInfo, generic: GenericAction) -> PerformAction {
        return PerformAction(pluginInfo: pluginInfo, actionMeta: generic, complete: { ctx in
            guard let executable = self.command.first, let pluginPath = self.pluginPath else { return }
            let environment = self.environment(pluginInfo: pluginInfo, generic: generic, context: ctx)
            do {
                let output = try await Task.detached {
                    try executeCommand(workdir: pluginPath, command: executable,
                                       arguments: Array(self.command.dropFirst()), withEnv: environment)
                }.value
                guard let output else { return }
                await MainActor.run {
                    if ctx.Editable && generic.after == .paste { pasteText(output) }
                    else if generic.after == .copy { copyText(output) }
                    else if generic.after == .show { WindowManager.shared.createTextWindow(output, editable: false) }
                    else if generic.after == .xshow { WindowManager.shared.createTextWindow(output, editable: ctx.Editable) }
                }
            } catch {
                let message = PluginRedactor(info: pluginInfo, values: pluginInfo.getOptionsValue()).redact(error.localizedDescription)
                AppLogger.plugin.error("Command failed: \(message)")
                await MainActor.run {
                    WindowManager.shared.createTextWindow("\(generic.title)：\(message)", editable: false)
                }
            }
        })
    }
}
