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
                    let pasteboard = NSPasteboard.general
                    let lastCopyText = pasteboard.string(forType: .string)
                    
                    pasteboard.clearContents()
                    pasteboard.setString(output, forType: .string)
                    PressPasteKey()
                    usleep(100000)
                    pasteboard.setString(lastCopyText ?? "", forType: .string)
                } else if generic.after == kAfterCopy {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(output, forType: .string)
                } else if generic.after == kAfterShow {
                    WindowManager.shared.createTextWindow(output)
                }
            }
        })
    }
    
}

private func executeCommand(
    workdir: String, command: String, arguments: [String] = [], withEnv env: [String:String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        process.currentDirectoryURL =  URL(fileURLWithPath: workdir)
       
        var copiedEnv = env
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            copiedEnv["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:" + path
        }
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

