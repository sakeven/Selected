import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView().tabItem {
                Label("General", systemImage: "gear")
            }
            PluginListView().tabItem {
                Label("Extensions", systemImage: "puzzlepiece")
            }
            ApplicationActionListView().tabItem {
                Label("Applications", systemImage: "apple.terminal")
            }
            ClipboardSettingsView().tabItem {
                Label("Clipboard", systemImage: "doc.on.clipboard.fill")
            }
        }
        .tint(.blue)
        .background(Color("SettingsBackground"))
        .frame(minWidth: 760, idealWidth: 940, minHeight: 600, idealHeight: 740)
    }
}

#Preview {
    SettingsView()
}
