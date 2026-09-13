import SwiftUI

@main
struct SelectedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(!isPreview)) {
            MenuItemView()
        } label: {
            Label {
                Text("Selected")
            } icon: {
                Image("SelectedMenuBar")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            }
            .help("Selected")
        }
        .menuBarExtraStyle(.menu)
        .commands {
            SelectedMainMenu()
        }.handlesExternalEvents(matching: [])
        Settings {
            if isPreview {
                PreviewHostView()
            } else {
                SettingsView()
            }
        }
    }
}
