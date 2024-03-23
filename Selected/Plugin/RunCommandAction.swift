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
    
    
    init(command: [String]) {
        self.command = command
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            guard self.command.count > 0 else {
                return
            }
            
            guard let pluginPath = self.pluginPath else {
                return
            }
            
            if let output = executeCommand(
                workdir: pluginPath,
                command: self.command[0],
                arguments: [String](self.command[1...]),
                withctx: ctx) {
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
                }
            }
        })
    }
    
}

private func executeCommand(
    workdir: String, command: String, arguments: [String] = [],withctx ctx: SelectedTextContext) -> String? {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        process.currentDirectoryURL =  URL(fileURLWithPath: workdir)
        process.environment = ["SELECTED_TEXT": ctx.Text, "SELECTED_BUNDLEID": ctx.BundleID]
        
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            process.environment?["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:" + path
        }
        
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

