//
//  Actions.swift
//  Selected
//
//  Created by sake on 2024/3/16.
//

import Foundation
import SwiftUI
import Yams
import AppKit
import Defaults

let kAfterPaste = "paste"
let kAfterCopy = "copy"

class GenericAction: Decodable {
    var title: String
    var icon: String
    var after: String
    var identifier: String
    var regex: String?
    var description: String?
    
    init(title: String, icon: String, after: String, identifier: String) {
        self.title = title
        self.icon = icon
        self.after = after
        self.identifier = identifier
    }
    
    init(title: String, icon: String, after: String, identifier: String, regex: String) {
        self.title = title
        self.icon = icon
        self.after = after
        self.identifier = identifier
        self.regex = regex
    }
    
    static func == (lhs: GenericAction, rhs: GenericAction) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

class URLAction: Decodable {
    var url: String
    
    init(url: String) {
        self.url = url
    }
    
    func generate(pluginInfo: PluginInfo, generic: GenericAction) -> PerformAction {
        
        return PerformAction(
             actionMeta: generic, complete: { ctx in
            
            let urlString = replaceOptions(content: self.url, selectedText: ctx.Text, options: pluginInfo.getOptionsValue())
            let url = URL(string: urlString)!
            
            NSLog(url.scheme ?? "")
            if url.scheme != "http" && url.scheme != "https" {
                // not a web link
                NSWorkspace.shared.open(url)
                return
            }
            
            if !isBrowser(id: ctx.BundleID){
                NSWorkspace.shared.open(url)
                return
            }
        
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ctx.BundleID) else {
                NSWorkspace.shared.open(url)
                return
            }
            
            let cfg =  NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: cfg)
        })
    }
}


class WebSearchAction {
    @Default(.search) var searchURL
    
    init() {
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        
        return PerformAction(
            actionMeta: generic, complete: { ctx in
            
            let urlString = replaceOptions(content: self.searchURL, selectedText: ctx.Text)
            
            let url = URL(string: urlString)!
            
            NSLog(url.scheme ?? "")
            if url.scheme != "http" && url.scheme != "https" {
                // not a web link
                NSWorkspace.shared.open(url)
                return
            }
            
            if !isBrowser(id: ctx.BundleID){
                NSWorkspace.shared.open(url)
                return
            }
        
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ctx.BundleID) else {
                NSWorkspace.shared.open(url)
                return
            }
            
            let cfg =  NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: cfg)
        })
    }
}

class ServiceAction: Decodable {
    var name: String
    
    init(name: String) {
        self.name = name
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            PerfomService(serviceName: self.name, text: ctx.Text)
        })
    }
}

class KeycomboAction: Decodable {
    // TODO validate keycombo
    var keycombo: String
    var keycombos: [String]?
    
    init(keycombo: String) {
        NSLog("set keycombo \(keycombo)")
        self.keycombo = keycombo
    }
    
    init(keycombos: [String]) {
        NSLog("set keycombos \(keycombos)")
        self.keycombos = keycombos
        self.keycombo = ""
    }
    
    func pressKeycombo(keycombo: String ){
        let list = self.keycombo.split(separator: " ")
        var flags = CGEventFlags(rawValue: 0)
        var keycode = UInt16(0)
        list.forEach { sub in
            let str = String(sub)
            if let mask = KeyMaskMapping[str]{
                flags.insert(mask)
            }
            if let key = KeycodeMapping[str] {
                keycode = key
            }
        }
        PressKey(keycode: keycode, flags:  flags)
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            if let keycombos = self.keycombos, !keycombos.isEmpty {
                for keycombo in keycombos {
                    self.pressKeycombo(keycombo: keycombo)
                    usleep(100000)
                }
            } else {
                self.pressKeycombo(keycombo: self.keycombo)
            }
        })
    }
}

class CopyAction: Decodable{
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            NSPasteboard.general.declareTypes([.string], owner: nil)
            let pasteboard = NSPasteboard.general
            pasteboard.setString(ctx.Text, forType: .string)
        })
    }
}


class GptAction: Decodable{
    var prompt: String
    
    init(prompt: String) {
        self.prompt = prompt
    }
    
    func generate(pluginInfo: PluginInfo,  generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            WindowManager.shared.createChatWindow(withText: ctx.Text, prompt: self.prompt, options: pluginInfo.getOptionsValue())
        })
    }
}

class TranslationAction: Decodable {
    var target: String
    
    init(target: String) {
        self.target = target
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            WindowManager.shared.createTranslationWindow(withText: ctx.Text, to: self.target)
        })
    }
}


struct Action: Decodable{
    var meta: GenericAction
    var url: URLAction?
    var service: ServiceAction?
    var keycombo: KeycomboAction?
    var gpt: GptAction?
    var runCommand: RunCommandAction?
}


class PerformAction: Identifiable,Hashable {
    var id = UUID()
    var actionMeta: GenericAction
    var complete: ((_: SelectedTextContext) -> Void)?
    var completeAsync: ((_: SelectedTextContext) async ->  Void)?

    
    func hash(into hasher: inout Hasher) {
        hasher.combine(actionMeta.identifier)
    }
    
    static func == (lhs: PerformAction, rhs: PerformAction) -> Bool {
        return lhs.actionMeta == rhs.actionMeta
    }
    
    init(actionMeta: GenericAction, complete: @escaping (_: SelectedTextContext) -> Void) {
        self.actionMeta = actionMeta
        self.complete = complete
    }
    
    init(actionMeta: GenericAction, complete: @escaping (_: SelectedTextContext) async -> Void) {
        self.actionMeta = actionMeta
        self.completeAsync = complete
    }
}

func GetAllActions() -> [PerformAction] {
    return PluginManager.shared.allActions
}

// GetActions 根据上下文获得当前支持的 action 列表。比如根据当前窗口的应用选择 action 列表。
func GetActions(ctx: SelectedTextContext) -> [PerformAction] {
    let condition = ConfigurationManager.shared.getAppCondition(bundleID: ctx.BundleID)
    let actionList = GetAllActions()
    
    guard let condition = condition else {
        return FilterActions(ctx, list: actionList)
    }
    
    if condition.actions.isEmpty {
        return FilterActions(ctx, list: actionList)
    }
    
    var list = [PerformAction]()
    let allActionDict = actionList.reduce(into: [String: PerformAction]()) {
        $0[$1.actionMeta.identifier] = $1
    }
    for action in condition.actions {
        guard let allowed = allActionDict[action] else {
            continue
        }
        list.append(allowed)
    }
    return FilterActions(ctx, list: list)
}

// If ctx isn't editable, not return editable actions.
func FilterActions(_ ctx: SelectedTextContext, list: [PerformAction] ) -> [PerformAction] {
    var filtered = [PerformAction]()
    for action in list {
        if !ctx.Editable && action.actionMeta.after == "paste" {
            continue
        }
        if let regexStr = action.actionMeta.regex {
           let reg = try! Regex(regexStr)
            if !ctx.Text.contains(reg) {
                continue
            }
        }
        filtered.append(action)
    }
    return filtered
}
