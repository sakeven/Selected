import Foundation

func GetAllActions() -> [PerformAction] {
    return PluginManager.shared.allActions
}

// GetActions 根据上下文获得当前支持的 action 列表。比如根据当前窗口的应用选择 action 列表。
func GetActions(ctx: SelectedTextContext, from actionList: [PerformAction] = GetAllActions(), configuration: UserConfiguration = ConfigurationManager.shared.userConfiguration) -> [PerformAction] {
    var actions = [ActionID]()
    if let condition = configuration.appCondition(bundleID: ctx.BundleID) {
        actions = condition.actions
    }
    if !ctx.WebPageURL.isEmpty {
        if let condition = configuration.urlCondition(url: ctx.WebPageURL) {
            actions = condition.actions
        }
    }

    if actions.isEmpty {
        return FilterActions(ctx, list: actionList)
    }

    var list = [PerformAction]()
    let allActionDict = actionList.reduce(into: [String: PerformAction]()) {
        $0[$1.actionMeta.identifier] = $1
    }
    for action in actions {
        guard let allowed = allActionDict[action] else {
            continue
        }
        list.append(allowed)
    }
    return FilterActions(ctx, list: list)
}

// If ctx isn't editable, not return editable actions.
func FilterActions(_ ctx: SelectedTextContext, list: [PerformAction] ) -> [PerformAction] {
    var filtered = [PerformAction]()
    var l = list
    // Here are default actions.
    l.append(OpenLinksAction().generate(
        generic: GenericAction(title: "OpenLinks", icon: "symbol:link", identifier: "selected.openlinks")
    ))
    l.append(MapAction().generate(generic: GenericAction(title: "Map", icon: "symbol:mappin.and.ellipse", identifier: "selected.map")))
    for action in l {
        if let supported = action.supported {
            if !supported(ctx) {
                continue
            }
        }

        if !action.actionMeta.matches(ctx) { continue }
        if !ctx.Editable && action.actionMeta.after == .paste {
            continue
        }

        filtered.append(action)
    }
    return filtered
}
