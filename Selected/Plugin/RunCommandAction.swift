//
//  ScriptAction.swift
//  Selected
//
//  Created by sake on 2024/3/19.
//

import Foundation
import AppKit


class RunCommandAction: Decodable {
    var command: [String]
    var pluginPath: String? // we will execute command in pluginPath.
    
    enum CodingKeys: String, CodingKey {
        case command
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        command = try values.decode([String].self, forKey: .command)
    }
    
    
    init(command: [String], options: [Option]) {
        self.command = command
    }
    
    func generate(pluginInfo: PluginInfo, generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            guard self.command.count > 0 else {
                return
            }
            
            guard let pluginPath = self.pluginPath else {
                return
            }
            
            
            let joinedURLs = ctx.URLs.joined(separator: "\n")
            
            var env = ["SELECTED_TEXT": ctx.Text,
                       "SELECTED_BUNDLEID": ctx.BundleID,
                       "SELECTED_ACTION": generic.identifier,
                       "SELECTED_WEBPAGE_URL": ctx.WebPageURL,
                       "SELECTED_URLS": joinedURLs]
            let optionVals = pluginInfo.getOptionsValue()
            optionVals.forEach{ (key: String, value: String) in
                env["SELECTED_OPTIONS_"+key.uppercased()] = value
            }
            if let path = ProcessInfo.processInfo.environment["PATH"] {
                env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:" + path
            }
            
            if let output = executeCommand(
                workdir: pluginPath,
                command: self.command[0],
                arguments: [String](self.command[1...]),
                withEnv: env) {
                if ctx.Editable && generic.after == kAfterPaste {
                    pasteText(output)
                } else if generic.after == kAfterCopy {
                    copyText(output)
                } else if generic.after == kAfterShow {
                    WindowManager.shared.createTextWindow(output)
                }
            }
        })
    }
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
    workdir: String, command: String, arguments: [String] = [], withEnv env: [String:String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        var path: String?
        if let p = ProcessInfo.processInfo.environment["PATH"] {
            path = "/opt/homebrew/bin:/opt/homebrew/sbin:" + p
        }
        
        let executableURL = findExecutablePath(commandName: command,
                                               currentDirectoryURL:  URL(fileURLWithPath: workdir),
                                               path: path)
        
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        process.currentDirectoryURL = URL(fileURLWithPath: workdir)
        
        var copiedEnv = env
        copiedEnv["PATH"] = path
        
        process.environment = copiedEnv
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print(output)
                return output
            }
        } catch {
            print("Failed to execute command: \(error.localizedDescription)")
        }
        return nil
    }


private func findExecutablePath(commandName: String, currentDirectoryURL: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first, path: String? = ProcessInfo.processInfo.environment["PATH"]) -> URL? {
    let fileManager = FileManager.default
    // 先检查是否是绝对路径
    let executableURL = URL(fileURLWithPath: commandName)
    if executableURL.isFileURL, fileManager.isExecutableFile(atPath: executableURL.path) {
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
