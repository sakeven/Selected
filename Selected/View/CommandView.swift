//
//  CommandView.swift
//  Selected
//
//  Created by sake on 2024/2/29.
//

import SwiftUI

struct SelectedMainMenu: Commands {
    @Environment(\.openURL)
    private var openURL

    var body: some Commands {
        // Help
        CommandGroup(replacing: CommandGroupPlacement.help, addition: {
            Button("Feedback") {
                openURL(URL(string: "https://github.com/sakeven/Selected/issues")!)
            }
        })
    }
}
