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

// pasteTextBefore: When there is a text selection, the cursor will move forward, then insert the text, which is equivalent to inserting the text before the currently seleted text.
// Note that some applications dot not support this operation and always insert the text after the currently selected text, such as Terminal.
func pasteTextBefore(_ text: String) {
    PressKey(keycode: Keycode.leftArrow)
    pasteText(text)
}

// pasteTextAfter: When there is a text selection, the cursor will move backward, then insert the text, which is equivalent to inserting the text after the currently seleted text.
// Note that some applications dot not support this operation and always insert the text after the currently selected text, such as Terminal.
func pasteTextAfter(_ text: String) {
    PressKey(keycode: Keycode.rightArrow)
    pasteText(text)
}


func pasteText(_ text: String) {
    let id = UUID().uuidString
    ClipService.shared.pauseMonitor(id)
    defer {
        ClipService.shared.resumeMonitor(id)
    }
    let pasteboard = NSPasteboard.general
    let previousItems: [NSPasteboardItem] = pasteboard.pasteboardItems?.map { item in
        let saved = NSPasteboardItem()
        for type in item.types {
            if let data = item.data(forType: type) { saved.setData(data, forType: type) }
        }
        return saved
    } ?? []

    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    let temporaryChangeCount = pasteboard.changeCount
    PressPasteKey()
    usleep(100000)
    if pasteboard.changeCount == temporaryChangeCount {
        pasteboard.clearContents()
        pasteboard.writeObjects(previousItems)
    }
}

func copyText(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

public func executeCommand(
    workdir: String, command: String, arguments: [String] = [], withEnv env: [String: String]) throws -> String? {
    let result = try executeCommandResult(workdir: workdir, command: command, arguments: arguments, withEnv: env)
    guard result.exitCode == 0 else {
        throw NSError(domain: "Selected.Command", code: Int(result.exitCode), userInfo: [
            NSLocalizedDescriptionKey: String(localized: "Command exit code: \(result.exitCode)") + (result.diagnostics.isEmpty ? "" : "\n" + result.diagnostics)
        ])
    }
    return result.output
}

func executeCommandResult(workdir: String, command: String, arguments: [String] = [], withEnv env: [String: String],
                          cancellation: CommandCancellation = CommandCancellation()) throws -> CommandResult {
    let path = "/opt/homebrew/bin:/opt/homebrew/sbin:" + (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
    guard let executable = findExecutablePath(commandName: command, currentDirectoryURL: URL(fileURLWithPath: workdir), path: path) else {
        throw NSError(domain: "Selected.Command", code: 127, userInfo: [NSLocalizedDescriptionKey: String(localized: "Executable not found: \(command)")])
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Selected-Command-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: directory) }
    let stdout = directory.appendingPathComponent("stdout")
    let stderr = directory.appendingPathComponent("stderr")
    FileManager.default.createFile(atPath: stdout.path, contents: nil, attributes: [.posixPermissions: 0o600])
    FileManager.default.createFile(atPath: stderr.path, contents: nil, attributes: [.posixPermissions: 0o600])
    let outputHandle = try FileHandle(forWritingTo: stdout)
    let errorHandle = try FileHandle(forWritingTo: stderr)
    defer { try? outputHandle.close(); try? errorHandle.close() }
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.currentDirectoryURL = URL(fileURLWithPath: workdir)
    process.environment = env.merging(["PATH": path]) { _, new in new }
    process.standardInput = FileHandle.nullDevice
    // Files avoid pipe deadlocks when a command spawns a background child.
    process.standardOutput = outputHandle
    process.standardError = errorHandle
    try cancellation.start(process)
    let timer = DispatchSource.makeTimerSource()
    timer.schedule(deadline: .now() + 60)
    timer.setEventHandler { cancellation.cancel(timedOut: true) }
    timer.activate()
    defer { timer.cancel() }
    process.waitUntilExit()
    try cancellation.check()
    return CommandResult(output: String(decoding: try Data(contentsOf: stdout), as: UTF8.self),
                         diagnostics: String(decoding: try Data(contentsOf: stderr), as: UTF8.self),
                         exitCode: process.terminationStatus)
}


private func findExecutablePath(commandName: String, currentDirectoryURL: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first, path: String? = ProcessInfo.processInfo.environment["PATH"]) -> URL? {
    let fileManager = FileManager.default
    // 先检查是否是绝对路径
    let executableURL = URL(fileURLWithPath: commandName)
    if (commandName as NSString).isAbsolutePath, fileManager.isExecutableFile(atPath: executableURL.path) {
        return executableURL
    }

    // 检查命令是否在当前目录
    if let currentDirectoryURL = currentDirectoryURL {
        let currentDirectoryExecutable = currentDirectoryURL.appendingPathComponent(commandName)
        if FileManager.default.isExecutableFile(atPath: currentDirectoryExecutable.path) {
            return currentDirectoryExecutable
        }
    }

    // 然后检查命令是否在 PATH 环境变量中的某个目录
    if let path = path {
        let paths = path.split(separator: ":").map { String($0) }
        for p in paths {
            let potentialURL = URL(fileURLWithPath: p).appendingPathComponent(commandName)
            if FileManager.default.isExecutableFile(atPath: potentialURL.path) {
                return potentialURL
            }
        }
    }

    // 如果找不到可执行文件返回 nil
    return nil
}
