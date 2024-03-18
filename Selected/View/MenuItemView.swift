//
//  MenuItemView.swift
//  Selected
//
//  Created by sake on 2024/2/28.
//


import SettingsAccess
import SwiftUI


struct MenuItemView: View {
    var body: some View {
        Group {
            settingItem
                .keyboardShortcut(.init(","))
            Divider()
            quitItem
                .keyboardShortcut(.init("q"))
        }
    }
    
    
    
    @ViewBuilder
    private var settingItem: some View {
        SettingsLink {
            Text("Settings...")
        } preAction: {
            NSLog("打开设置")
            NSApp.activate(ignoringOtherApps: true)
        } postAction: {
            // nothing to do
        }
    }
    
    @ViewBuilder
    private var quitItem: some View {
        Button("quit") {
            NSLog("退出应用")
            NSApplication.shared.terminate(nil)
        }
    }
}

#Preview {
    MenuItemView()
}
