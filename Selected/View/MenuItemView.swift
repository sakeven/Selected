//
//  MenuItemView.swift
//  Selected
//
//  Created by sake on 2024/2/28.
//


import SettingsAccess
import SwiftUI


struct MenuItemView: View {
    @Environment(\.openURL)
    private var openURL
    
    var body: some View {
        Group {
            settingItem
                .keyboardShortcut(.init(","))
            Divider()
            feedbackItem
            docItem
            aboutItem
            Divider()
            quitItem
                .keyboardShortcut(.init("q"))
        }
    }
    
    @ViewBuilder
    private var aboutItem: some View {
        Button("About") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(nil)
        }
    }
    
    @ViewBuilder
    private var feedbackItem: some View {
        Button("Feedback") {
            openURL(URL(string: "https://github.com/sakeven/Selected/issues")!)
        }
    }
    
    @ViewBuilder
    private var docItem: some View {
        Button("Document") {
            openURL(URL(string: "https://github.com/sakeven/Selected?tab=readme-ov-file#%E5%8A%9F%E8%83%BD")!)
        }
    }
    
    @ViewBuilder
    private var settingItem: some View {
        SettingsLink {
            Text("Settings")
        } preAction: {
            NSLog("打开设置")
            NSApp.activate(ignoringOtherApps: true)
        } postAction: {
            // nothing to do
        }
    }
    
    @ViewBuilder
    private var quitItem: some View {
        Button("Quit") {
            NSLog("退出应用")
            NSApplication.shared.terminate(nil)
        }
    }
}

#Preview {
    MenuItemView()
}
