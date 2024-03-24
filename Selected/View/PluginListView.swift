//
//  PluginListView.swift
//  Selected
//
//  Created by sake on 2024/3/18.
//

import Foundation
import SwiftUI


struct PluginListView: View {
    @State var pluginList = PluginManager.shared.plugins
    
    var body: some View {
        
        List{
            ForEach(pluginList, id: \.self.info.name) { plugin in
                Label(
                    title: { Text(plugin.info.name).padding(.leading, 10) },
                    icon: { Icon(plugin.info.icon)}
                ).padding(10).contextMenu {
                    Button(action: {
                        // TODO
                        NSLog("delete \(plugin.info.name)")
                    }){
                        Text("Delete")
                    }
                }
            }
        }
    }
}

#Preview {
    PluginListView()
}



struct ActionListView: View {
    @State var actionList = GetAllActions()
    
    var body: some View {
        List{
            ForEach(actionList, id: \.self.actionMeta.identifier) { action in
                Label(
                    title: { Text(action.actionMeta.title).padding(.leading, 10) },
                    icon: { Icon(action.actionMeta.icon) }
                ).padding(10)
            }
        }
    }
}

#Preview {
    ActionListView()
}

struct ApplicationActionListView: View {
    @State var cfg = ConfigurationManager.shared.userConfiguration
    
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
        List{
            ForEach($cfg.appConditions, id: \.self.bundleID) { $app in
                DisclosureGroup {
                            ForEach($app.actions, id: \.self) { $id in
                                if let action = getAction(id) {
                                    Label(
                                        title: { Text(action.actionMeta.title).padding(.leading, 10)
                                            Spacer()
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .onTapGesture {
                                                    NSLog("clicked")
                                                }
                                        },
                                        icon: { Icon(action.actionMeta.icon) }
                                    ).padding(10)
                                }
                            }.onMove(perform: { indices, newOffset in
                                withAnimation {
                                    app.actions.move(fromOffsets: indices, toOffset: newOffset)
                                    ConfigurationManager.shared.userConfiguration = cfg
                                    ConfigurationManager.shared.saveConfiguration()
                                }
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

#Preview {
    ApplicationActionListView()
}
