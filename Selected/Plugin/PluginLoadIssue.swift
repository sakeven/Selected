import Foundation

struct PluginLoadIssue: Identifiable {
    let directory: URL
    let message: String
    var id: String { directory.path }
}
