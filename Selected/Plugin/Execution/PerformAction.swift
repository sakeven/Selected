import Foundation
import AppKit

class PerformAction: Identifiable,Hashable {
    var id = UUID()
    var actionMeta: GenericAction
    var pluginInfo: PluginInfo?
    var complete: ((_: SelectedTextContext) -> Void)?
    var completeAsync: ((_: SelectedTextContext) async ->  Void)?
    var supported: ((_: SelectedTextContext) -> Bool)?


    func hash(into hasher: inout Hasher) {
        hasher.combine(actionMeta.identifier)
    }

    static func == (lhs: PerformAction, rhs: PerformAction) -> Bool {
        return lhs.actionMeta == rhs.actionMeta
    }

    init(actionMeta: GenericAction, complete: @escaping (_: SelectedTextContext) -> Void) {
        self.actionMeta = actionMeta
        self.complete = complete
    }

    init(pluginInfo: PluginInfo, actionMeta: GenericAction, complete: @escaping (_: SelectedTextContext) -> Void) {
        self.actionMeta = actionMeta
        self.complete = complete
        self.pluginInfo = pluginInfo
    }

    init(actionMeta: GenericAction, complete: @escaping (_: SelectedTextContext) async -> Void) {
        self.actionMeta = actionMeta
        self.completeAsync = complete
    }

    init(pluginInfo: PluginInfo, actionMeta: GenericAction, complete: @escaping (_: SelectedTextContext) async -> Void) {
        self.actionMeta = actionMeta
        self.completeAsync = complete
        self.pluginInfo = pluginInfo
    }
}
