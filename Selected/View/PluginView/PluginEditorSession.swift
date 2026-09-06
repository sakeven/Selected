import Foundation

struct PluginEditorSession: Identifiable {
    let id = UUID()
    var plugin: Plugin
    let existing: Plugin?
}
