//
//  PluginInfo.swift
//  Selected
//
//  Created by sake on 2024/3/11.
//

import Foundation
import SwiftUI
import Yams


struct PluginInfo: Decodable {
    var icon: String
    var name: String
    var version: String?
    var minSelectedVersion: String?
    var description: String?
    var options: [Option]
    
    // not in config
    var enabled: Bool = true
    var pluginDir = ""
    
    
    enum CodingKeys: String, CodingKey {
        case icon, name, version, minSelectedVersion, description, options
    }
    
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.icon = try values.decode(String.self, forKey: .icon)
        self.name = try values.decode(String.self, forKey: .name)
        
        if values.contains(.version) {
            self.version = try values.decode(String.self, forKey: .version)
        }
        if values.contains(.minSelectedVersion) {
            self.minSelectedVersion = try values.decode(String.self, forKey: .minSelectedVersion)
        }
        if values.contains(.description) {
            self.description = try values.decode(String.self, forKey: .description)
        }
        self.options = [Option]()
        if values.contains(.options) {
            self.options = try values.decode([Option].self, forKey: .options)
        }
    }
}

struct Plugin: Decodable {
    var info: PluginInfo
    var actions: [Action]
}


// PluginManager 管理各种插件。插件保存在 ”Library/Application Support/Selected/Extensions“。
class PluginManager: ObservableObject {
    private var extensionsDir: URL
    private let filemgr = FileManager.default
    
    @Published var plugins = [Plugin]()
    
    static let shared = PluginManager()

    init(){
        let fileManager = FileManager.default
        // 应用程序子目录
        extensionsDir = appSupportURL.appendingPathComponent("Extensions", isDirectory: true)

        // 检查目录是否存在，否则尝试创建它
        if !fileManager.fileExists(atPath: extensionsDir.path) {
            try! fileManager.createDirectory(at: extensionsDir, withIntermediateDirectories: true, attributes: nil)
        }
        NSLog("Application Extensions Directory: \(extensionsDir.path)")
    }
    
    private func copyFile(fpath: String, tpath: String) -> Bool{
        NSLog("install from \(fpath) to \(tpath)")
        if filemgr.contentsEqual(atPath: fpath, andPath: tpath) {
            return false
        }
        do{
            NSLog("install to \(tpath)")
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: tpath){
                try fileManager.removeItem(atPath: tpath)
            }
            
            try fileManager.copyItem(atPath: fpath, toPath: tpath)
            return true
        } catch {
            print("install: an unexpected error: \(error)")
        }
        return false
    }
    
    func install(url: URL) {
        if url.hasDirectoryPath {
            NSLog("install \(url.lastPathComponent)")
            if copyFile(fpath: url.path(percentEncoded: false), tpath: extensionsDir.appending(component: url.lastPathComponent).path(percentEncoded: false)) {
                loadPlugins()
            }
        }
    }
    
    func remove(_ pluginDir: String) {
        do {
           try filemgr.removeItem(at:  extensionsDir.appendingPathComponent(pluginDir, isDirectory: true))
        } catch{
            NSLog("remove plugin \(pluginDir): \(error)")
        }
        loadPlugins()
    }
    
    func getPlugins() -> [Plugin] {
        return self.plugins
    }
    
    func loadPlugins(){
        var list = [Plugin]()
        let pluginDirs = try! filemgr.contentsOfDirectory(atPath: extensionsDir.path)
        NSLog("plugins \(pluginDirs)")
        for pluginDir in pluginDirs {
            let cfgPath = extensionsDir.appendingPathComponent(pluginDir, isDirectory: true).appendingPathComponent("config.yaml", isDirectory: false)
            if filemgr.fileExists(atPath: cfgPath.path) {
                let readFile = try! String(contentsOfFile: cfgPath.path, encoding: String.Encoding.utf8)
                let decoder = YAMLDecoder()
                var plugin: Plugin = try! decoder.decode(Plugin.self, from: readFile.data(using: .utf8)!)
                NSLog("plugin \(plugin)")
                
                plugin.info.pluginDir = pluginDir
                if plugin.info.icon.hasPrefix("file://./"){
                    plugin.info.icon = "file://"+extensionsDir.appendingPathComponent(pluginDir, isDirectory: true).appendingPathComponent(plugin.info.icon.trimPrefix("file://./"), isDirectory: false).path
                }
                
                for action in plugin.actions {
                    do {
                        if action.meta.icon.hasPrefix("file://./"){
                            action.meta.icon =  "file://"+extensionsDir.appendingPathComponent(pluginDir, isDirectory: true).appendingPathComponent(action.meta.icon.trimPrefix("file://./"), isDirectory: false).path
                        }
                        
                        if let runCommand = action.runCommand {
                            runCommand.pluginPath = extensionsDir.appendingPathComponent(pluginDir, isDirectory: true).path
                        }
                        
                        if let regex = action.meta.regex {
                            _ = try Regex(regex)
                        }
                    } catch {
                        NSLog("validate action error \(error)")
                    }
                }
                
                list.append(plugin)
            }
        }
        self.plugins = list
    }
    
    var allActions: [PerformAction] {
        var list = [PerformAction]()
        list.append(WebSearchAction().generate(
            generic: GenericAction(title: "Search", icon: "symbol:magnifyingglass", after: "", identifier: "selected.websearch")
        ))
        
        let pluginList = plugins
        pluginList.forEach { Plugin in
            if !Plugin.info.enabled {
                return
            }
            Plugin.actions.forEach { Action in
                if let url = Action.url {
                    list.append(url.generate(generic: Action.meta))
                    return
                }
                if let service =  Action.service {
                    list.append(service.generate(generic: Action.meta))
                    return
                }
                if let keycombo = Action.keycombo {
                    list.append(keycombo.generate(generic: Action.meta))
                    return
                }
                if let gpt =  Action.gpt {
                    list.append(gpt.generate(generic: Action.meta))
                    return
                }
                if let script = Action.runCommand {
                    list.append(script.generate(generic: Action.meta))
                    return
                }
            }
        }
        
        //    list.append(GptAction(prompt: "{text}").generate(
        //    generic: GenericAction(title: "chat", icon: "character.bubble", after: "", identifier: "selected.chat")
        //    ))
        list.append(TranslationAction(target: "cn").generate(
            generic: GenericAction(title: "翻译到中文", icon: "square 译中", after: "", identifier: "selected.translation.cn")
        ))
        list.append(TranslationAction(target: "en").generate(
            generic: GenericAction(title: "Translate to English", icon: "symbol:e.square", after: "", identifier: "selected.translation.en")
        ))
        list.append(URLAction(url: "{text}" ).generate(
            generic: GenericAction(title: "OpenLinks", icon: "symbol:link", after: "", identifier: "selected.openlinks")
        ))
        list.append(CopyAction().generate(
            generic: GenericAction(title: "Copy", icon: "symbol:doc.on.clipboard", after: "", identifier: "selected.copy")
        ))
        list.append(SpeackAction().generate(
            generic: GenericAction(title: "Speak", icon: "symbol:play.circle", after: "", identifier: "selected.speak")
        ))
        return list
    }
}
