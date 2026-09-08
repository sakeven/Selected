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
                Image(systemName: "pencil.and.scribble")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
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
