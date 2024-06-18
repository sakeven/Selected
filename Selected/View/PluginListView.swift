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
                                    pluginMgr.remove(plugin.info.pluginDir, plugin.info.name)
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
        self._text = State(initialValue: self.option.defaultVal ?? "")
        
        if self.option.type == .boolean {
            self._toggle = State(initialValue: getBoolOption(pluginName: pluginName, identifier: self.option.identifier))
            NSLog("value \(getBoolOption(pluginName: pluginName, identifier: self.option.identifier))")
        } else {
            if let text = getStringOption(pluginName: pluginName, identifier: self.option.identifier) {
                self._text = State(initialValue: text)
            }
        }
    }
    
    var body: some View {
        switch option.type {
            case .boolean:
                Toggle(option.identifier, isOn: $toggle).onChange(of: toggle) { newValue in
                    NSLog("value changed \(newValue)")
                    setOption(pluginName: pluginName, identifier: option.identifier, val: newValue)
                }
            case .multiple:
                Picker(option.identifier, selection: $text, content: {
                    ForEach(option.values!, id: \.self) {
                        Text($0)
                    }
                }).pickerStyle(DefaultPickerStyle()).onChange(of: text) {  newValue in
                    setOption(pluginName: pluginName, identifier: option.identifier, val: newValue)
                }
            case .string:
                TextField(option.identifier, text: $text).onChange(of: text) { newValue in
                    setOption(pluginName: pluginName, identifier: option.identifier, val: newValue)
                }
            case .secret:
                SecureField(option.identifier, text: $text).onChange(of: text) { newValue in
                    setOption(pluginName: pluginName, identifier: option.identifier, val: newValue)
                }
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
                        title: { Text(action.actionMeta.title).padding(.leading, 10)
                        },
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

