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
let kAfterShow = "show"

struct GenericAction: Decodable {
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

extension URL {
    func setScheme(_ value: String) -> URL {
        let components = NSURLComponents.init(url: self, resolvingAgainstBaseURL: true)
        components?.scheme = value
        return (components?.url!)!
    }
}

class OpenLinksAction: Decodable {
    func supported(ctx: SelectedTextContext) -> Bool {
        return !ctx.URLs.isEmpty
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        let pa = PerformAction(
            actionMeta: generic, complete: { ctx in
                NSLog("should open \(ctx.URLs)")
                
                for urlString in ctx.URLs {
                    NSLog("open \(urlString)")
                    var url = URL(string: urlString)!
                    
                    if url.scheme == nil || url.scheme == "" {
                        url = url.setScheme("https")
                    }
                    
                    DispatchQueue.main.async {
                        if url.scheme != "http" && url.scheme != "https"  {
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
                    }
                }
            })
        pa.supported = supported
        return pa
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


class MapAction {
    func supported(ctx: SelectedTextContext) -> Bool {
        return !ctx.Address.isEmpty
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        let pa = PerformAction(
            actionMeta: generic, complete: { ctx in
                let url = URL(string: "maps://?q="+ctx.Address)!
                NSWorkspace.shared.open(url)
            })
        pa.supported = supported
        return pa
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
    
    var supported: Supported? // supported urls or apps
    
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
    
    private func isMatched(bundleID: String, url: String) -> Bool {
        guard let supported = self.supported else{
            return true
        }
       return supported.match(url: url, bundleID: bundleID)
    }
    
    func supported(ctx: SelectedTextContext) -> Bool {
        return isMatched(bundleID: ctx.BundleID, url: ctx.WebPageURL)
    }
    
    func generate(pluginInfo: PluginInfo, generic: GenericAction) -> PerformAction {
        let pa = PerformAction(pluginInfo: pluginInfo, actionMeta:
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
        pa.supported = self.supported
        return pa
    }
}

class CopyAction: Decodable{
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            NSPasteboard.general.declareTypes([.string], owner: nil)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(ctx.Text, forType: .string)
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
    var pluginInfo: PluginInfo?
    var complete: ((_: SelectedTextContext) -> Void)?
    var completeAsync: ((_: SelectedTextContext) async ->  Void)?
    var supported: ((_: SelectedTextContext) -> Bool)?
    
    
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
    
    init(pluginInfo: PluginInfo, actionMeta: GenericAction, complete: @escaping (_: SelectedTextContext) -> Void) {
        self.actionMeta = actionMeta
        self.complete = complete
        self.pluginInfo = pluginInfo
    }
    
    init(actionMeta: GenericAction, complete: @escaping (_: SelectedTextContext) async -> Void) {
        self.actionMeta = actionMeta
        self.completeAsync = complete
    }
    
    init(pluginInfo: PluginInfo, actionMeta: GenericAction, complete: @escaping (_: SelectedTextContext) async -> Void) {
        self.actionMeta = actionMeta
        self.completeAsync = complete
    }
}

func GetAllActions() -> [PerformAction] {
    return PluginManager.shared.allActions
}

// GetActions 根据上下文获得当前支持的 action 列表。比如根据当前窗口的应用选择 action 列表。
func GetActions(ctx: SelectedTextContext) -> [PerformAction] {
    var actions = [ActionID]()
    if let condition = ConfigurationManager.shared.getAppCondition(bundleID: ctx.BundleID) {
        actions = condition.actions
    }
    if !ctx.WebPageURL.isEmpty {
        if let condition = ConfigurationManager.shared.getURLCondition(url: ctx.WebPageURL) {
            actions = condition.actions
        }
    }
    
    let actionList = GetAllActions()
    if actions.isEmpty {
        return FilterActions(ctx, list: actionList)
    }
    
    var list = [PerformAction]()
    let allActionDict = actionList.reduce(into: [String: PerformAction]()) {
        $0[$1.actionMeta.identifier] = $1
    }
    for action in actions {
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
    var l = list
    // Here are default actions.
    l.append(OpenLinksAction().generate(
        generic: GenericAction(title: "OpenLinks", icon: "symbol:link", after: "", identifier: "selected.openlinks")
    ))
    l.append(MapAction().generate(generic: GenericAction(title: "Map", icon: "symbol:mappin.and.ellipse", after: "", identifier: "selected.map")))
    for action in l {
        if let supported = action.supported {
            if !supported(ctx) {
                continue
            }
        }
        
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

