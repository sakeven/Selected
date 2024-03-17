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
    var miniSelectedVersion: String?
    var description: String?
    var enabled: Bool = true
}

struct Plugin: Decodable {
    var info: PluginInfo
    var actions: [Action]
}

var PluginList: [Plugin] = [
    Plugin(info:
            PluginInfo(
                icon: "magnifyingglass",
                name: "Web Search",
                enabled: true),
           actions: [
            Action(
                meta: GenericAction(title: "Search", icon: "magnifyingglass",
                                    after: "", identifier: "selected.websearch"),
                url:
                    URLAction(
                        url: "https://www.google.com.hk/search?q={text}")
            )]),
    
    Plugin(info:
            PluginInfo(
                icon: "mappin.and.ellipse",
                name: "Maps",
                enabled: false),
           actions: [
            Action(
                meta: GenericAction(title: "Maps", icon: "mappin.and.ellipse",
                                    after: "", identifier: "selected.map"),
                url:
                    URLAction(
                        url:  "maps://?q={text}")
            )])
]

// PluginManager 管理各种插件。插件保存在 ”Library/Application Support/Selected/Extensions“。
class PluginManager {
    private var extensionsDir: URL
    private let filemgr = FileManager.default
    var plugins = [Plugin]()

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
                if plugin.info.icon.hasPrefix("file://./"){
                    plugin.info.icon = "file://"+extensionsDir.appendingPathComponent(pluginDir, isDirectory: true).appendingPathComponent(plugin.info.icon.trimPrefix("file://./"), isDirectory: false).path
                }
                for action in plugin.actions {
                    if action.meta.icon.hasPrefix("file://./"){
                        action.meta.icon =  "file://"+extensionsDir.appendingPathComponent(pluginDir, isDirectory: true).appendingPathComponent(action.meta.icon.trimPrefix("file://./"), isDirectory: false).path
                    }
                }
                list.append(plugin)
            }
        }
        self.plugins = list
    }
}
