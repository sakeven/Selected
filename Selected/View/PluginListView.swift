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
