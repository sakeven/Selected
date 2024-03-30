//
//  PluginListView.swift
//  Selected
//
//  Created by sake on 2024/3/18.
//

import Foundation
import SwiftUI

struct PluginListView: View {
    @ObservedObject var pluginMgr = PluginManager.shared
    
    var body: some View {
        VStack{
            List{
                ForEach($pluginMgr.plugins, id: \.self.info.name) { $plugin in
                    DisclosureGroup{
                        if !$plugin.info.options.isEmpty {
                            Form{
                                Section("Options"){
                                    ForEach($plugin.info.options, id: \.self.identifier) {
                                        $option in
                                        OptionView(pluginName: plugin.info.name, option: $option)
                                    }
                                }
                            }.formStyle(.grouped).scrollContentBackground(.hidden)
                        }
                    } label: {
                        HStack{
                            Label(
                                title: { Text(plugin.info.name).padding(.leading, 10)
                                    if let desc = plugin.info.description {
                                        Text(desc).font(.system(size: 10))
                                    }
                                },
                                icon: { Icon(plugin.info.icon)}
                            ).padding(10).contextMenu {
                                Button(action: {
                                    NSLog("delete \(plugin.info.name)")
                                    pluginMgr.remove(plugin.info.pluginDir)
                                }){
                                    Text("Delete")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    PluginListView()
}

struct OptionView: View {
    var pluginName: String
    @Binding var option: Option
    
    @State private var toggle: Bool = false
    @State private var text: String = ""
    
    init(pluginName: String, option: Binding<Option>) {
        self._option = option
        self.pluginName = pluginName
        self.text = option.wrappedValue.defaultVal ?? ""
    }
    
    var body: some View {
        switch option.type {
            case .boolean:
                Toggle(option.identifier, isOn: $toggle)
            case .multiple:
                Picker(option.identifier, selection: $text, content: {
                    ForEach(option.values!, id: \.self) {
                        Text($0)
                    }
                }).pickerStyle(DefaultPickerStyle())
            case .string:
                TextField(option.identifier, text: $text)
            case .secret:
                SecureField(option.identifier, text: $text)
        }
    }
}


struct ActionListView: View {
    @ObservedObject var pluginMgr = PluginManager.shared
    
    
    var body: some View {
        List{
            ForEach(pluginMgr.allActions, id: \.self.actionMeta.identifier) { action in
                HStack{
                    Label(
                        title: { Text(action.actionMeta.title).padding(.leading, 10) },
                        icon: { Icon(action.actionMeta.icon) }
                    ).padding(10)
                    if let desc = action.actionMeta.description {
                        Text(desc).font(.system(size: 10))
                    }
                }
            }
        }
    }
}

#Preview {
    ActionListView()
}

struct ApplicationActionListView: View {
    @State var cfg = ConfigurationManager.shared.userConfiguration
    @State var toAddApp = ""
    @State var toAddAction = ""
    
    func getAction(_ id: String) -> PerformAction? {
        let actionList = GetAllActions()
        for action in actionList {
            if action.actionMeta.identifier == id {
                return action
            }
        }
        return nil
    }
    
    var body: some View {
        VStack{
            
            List{
                ForEach($cfg.appConditions, id: \.self.bundleID) { $app in
                    DisclosureGroup{
                        ForEach($app.actions, id: \.self) { $id in
                            if let action = getAction(id) {
                                Label(
                                    title: { Text(action.actionMeta.title).padding(.leading, 10)
                                        Spacer()
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .onTapGesture {
                                                app.actions.remove(at: app.actions.firstIndex(of: id)!)
                                                ConfigurationManager.shared.userConfiguration = cfg
                                                ConfigurationManager.shared.saveConfiguration()
                                            }
                                    },
                                    icon: { Icon(action.actionMeta.icon) }
                                ).padding(10)
                            }
                        }
                        .onMove(perform: { indices, newOffset in
                            withAnimation {
                                app.actions.move(fromOffsets: indices, toOffset: newOffset)
                                ConfigurationManager.shared.userConfiguration = cfg
                                ConfigurationManager.shared.saveConfiguration()
                            }
                        })
                        
                        OnePicker(exceptActions: $app.actions, onChange: { new in
                            if app.actions.contains(where: {
                                item in
                                return item == new
                            }) {
                                return
                            }
                            app.actions.append(new)
                            ConfigurationManager.shared.userConfiguration = cfg
                            ConfigurationManager.shared.saveConfiguration()
                        })
                    } label: {
                        Label(
                            title: {
                                Text(getAppName(app.bundleID)).padding(.leading, 10)
                            },
                            icon: { getIcon(app.bundleID)}
                        ).padding(10)
                    }
                }
                
                
                Picker("Add", selection: $toAddApp, content: {
                    HStack{
                        Text("select one app")
                    }.tag("")
                    
                    ForEach(getAllApplications(), id: \.self.id) { app in
                        HStack{
                            app.iconImage()
                            Text(app.localizedName)
                        }
                    }
                }).onChange(of: toAddApp, { old, new in
                    if new == "" {
                        return
                    }
                    cfg.appConditions.append(AppCondition(bundleID: new, actions: []))
                    ConfigurationManager.shared.userConfiguration = cfg
                    ConfigurationManager.shared.saveConfiguration()
                    toAddApp = ""
                })
                .padding(.top, 10)
            }
        }
    }
    
    
    func getAllApplications() -> [Application] {
        var apps: [String: Application] = [:]
        for app in  NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier else {
                continue
            }
            
            guard let icon = app.icon else {
                continue
            }
            
            guard let localizedName = app.localizedName else {
                continue
            }
            
            
            if app.isHidden {
                continue
            }
            apps[id] = Application(id: id, icon: Image(nsImage: icon), localizedName: localizedName)
        }
        for app in cfg.appConditions {
            apps.removeValue(forKey: app.bundleID)
        }
        return apps.map { $1 }.sorted { app1, app2 in
            app1.id > app2.id
        }
    }
    
    func getAppName(_ bundleID: String) -> String {
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
        return FileManager.default.displayName(atPath: bundleURL.path)
    }
    
    func getIcon(_ bundleID: String) -> Image {
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
        return Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path))
    }
}

struct Application: Identifiable {
    let id: String
    var icon: Image
    let localizedName: String
    
    func iconImage() -> Image {
        return self.icon
    }
}

struct OnePicker: View {
    @Binding var exceptActions: [ActionID]
    var onChange: (_: String) -> Void
    
    @State private var toAddAction = ""
    
    var body: some View {
        Picker("Add", selection: $toAddAction, content: {
            HStack{
                Text("select an action")
            }.tag("")
            ForEach(getAllActionsExcept(exceptActions), id: \.self.actionMeta.identifier) { action in
                Text(action.actionMeta.title)
            }
        }).onChange(of: toAddAction, { old, new in
            if new == "" {
                return
            }
            onChange(new)
            toAddAction = ""
        })
    }
}

private func getAllActionsExcept(_ actions: [ActionID]) -> [PerformAction] {
    let allActions = GetAllActions()
    var ret = [PerformAction]()
    for action in allActions {
        if actions.contains(where: {
            item in
            return item == action.actionMeta.identifier
        }){
            continue
        }
        ret.append(action)
    }
    return ret
}

#Preview {
    ApplicationActionListView()
}
