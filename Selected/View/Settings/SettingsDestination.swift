import SwiftUI

enum SettingsDestination: String, CaseIterable, Identifiable {
    case general, extensions, applications, clipboard

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .extensions: "Extensions"
        case .applications: "Applications"
        case .clipboard: "Clipboard"
        }
    }

    var icon: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .extensions: "puzzlepiece.extension"
        case .applications: "square.grid.2x2"
        case .clipboard: "clipboard"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .general: "1"
        case .extensions: "2"
        case .applications: "3"
        case .clipboard: "4"
        }
    }
}
