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

    func generate(pluginInfo: PluginInfo, generic: GenericAction) -> PerformAction {
        return PerformAction(pluginInfo: pluginInfo, actionMeta: generic, complete: { ctx in
            guard let executable = self.command.first, let pluginPath = self.pluginPath else { return }
            var env = ["SELECTED_TEXT": ctx.Text,
                       "SELECTED_PLUGIN": pluginInfo.id,
                       "SELECTED_PLUGIN_VERSION": pluginInfo.version ?? "",
                       "SELECTED_EDITABLE": ctx.Editable.description,
                       "SELECTED_BUNDLEID": ctx.BundleID,
                       "SELECTED_ACTION": generic.identifier,
                       "SELECTED_WEBPAGE_URL": ctx.WebPageURL,
                       "SELECTED_URLS": ctx.URLs.joined(separator: "\n")]
            for (key, value) in pluginInfo.getOptionsValue() {
                env["SELECTED_OPTIONS_" + key.uppercased()] = value
            }
            let environment = env
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
                AppLogger.plugin.error("Command failed: \(error.localizedDescription)")
                await MainActor.run {
                    WindowManager.shared.createTextWindow("\(generic.title)：\(error.localizedDescription)", editable: false)
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
    let lastCopyText = pasteboard.string(forType: .string)

    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    PressPasteKey()
    usleep(100000)
    pasteboard.setString(lastCopyText ?? "", forType: .string)
}

func copyText(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

public func executeCommand(
    workdir: String, command: String, arguments: [String] = [], withEnv env: [String:String]) throws -> String? {
        let process = Process()
        process.qualityOfService = .default
        let stdOutPipe = Pipe()
        let stdErrPipe = Pipe()
        var path: String?
        if let p = ProcessInfo.processInfo.environment["PATH"] {
            path = "/opt/homebrew/bin:/opt/homebrew/sbin:" + p
        }

        guard let executableURL = findExecutablePath(commandName: command,
                                                     currentDirectoryURL: URL(fileURLWithPath: workdir), path: path) else {
            throw NSError(domain: "Selected.Command", code: 127, userInfo: [
                NSLocalizedDescriptionKey: "找不到可执行命令：\(command)"
            ])
        }
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdOutPipe
        process.standardError = stdErrPipe
        process.currentDirectoryURL = URL(fileURLWithPath: workdir)

        var copiedEnv = env
        copiedEnv["PATH"] = path
        process.environment = copiedEnv

        var stdOutData = Data()
        var stdErrData = Data()

        // Create a Dispatch group to handle reading from pipes asynchronously
        let group = DispatchGroup()

        // Asynchronously read stdout
        group.enter()
        stdOutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                stdOutPipe.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                stdOutData.append(data)
            }
        }

        // Asynchronously read stderr
        group.enter()
        stdErrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                stdErrPipe.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                stdErrData.append(data)
            }
        }


        let timeout: TimeInterval = 60 // 1 min
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            if process.isRunning {
                process.terminate()
                logger.warning("Process terminated due to timeout.")
            }
            timer.cancel()
        }

        defer {
            timer.cancel()
            stdOutPipe.fileHandleForReading.readabilityHandler = nil
            stdErrPipe.fileHandleForReading.readabilityHandler = nil
        }
        timer.activate()
        try process.run()
        process.waitUntilExit()

        // Ensure all data has been read
        group.wait()

        guard process.terminationStatus == 0 else {
            let message = String(data: stdErrData, encoding: .utf8) ?? ""
            throw NSError(domain: "Selected.Command", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "命令退出码 \(process.terminationStatus)\(message.isEmpty ? "" : "：" + message)"
            ])
        }
        return String(data: stdOutData, encoding: .utf8)
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
