//
//  HoverBallView.swift
//  Selected
//
//  Created by sake on 2024/3/9.
//

import SwiftUI
import MathParser

struct PopBarView: View {
    var actions:  [PerformAction]
    let ctx: SelectedTextContext
    let target: ActionTarget = ActionTarget()
    private let resultPosition = NSEvent.mouseLocation

    var showSharingButton = true
    var onClick: (() -> Void)?

    @Environment(\.openURL) var openURL

    var body: some View {
        HStack(spacing: 2) {
            ForEach(actions) { action in
                BarButton(icon: action.actionMeta.icon, title: action.actionMeta.title , clicked: {
                    $isLoading in
                    if let onClick = onClick {
                        onClick()
                    }
                    isLoading = true
                    if let pluginID = action.pluginInfo?.id,
                       let plugin = PluginManager.shared.plugins.first(where: { $0.id == pluginID }),
                       let definition = plugin.actions.first(where: { $0.meta.identifier == action.actionMeta.identifier }) {
                        ActionCoordinator.perform(.plugin(plugin, definition), input: ActionInput(context: ctx), target: target,
                                                                       resultPosition: resultPosition)
                        isLoading = false
                        return
                    }
                    if let complete =  action.complete {
                        complete(ctx)
                        isLoading = false
                    } else if let complete =  action.completeAsync {
                        Task {
                            await complete(ctx)
                            isLoading = false
                        }
                    }
                })
            }
            if showSharingButton {
                if !actions.isEmpty {
                    Divider().frame(height: 16).padding(.horizontal, 3)
                }
                SharingButton(message: ctx.Text)
            }
            if let res = calculate(ctx.Text) {
                if !actions.isEmpty || showSharingButton {
                    Divider().frame(height: 16).padding(.horizontal, 3)
                }
                let v = valueFormatter.string(from: NSNumber(value: res))!
                NumerberView(value: v)
            }
        }
        .padding(5)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.10), lineWidth: 0.5)
        }
        .fixedSize()
    }
}


#Preview {
    PopBarView(actions: GetActions(ctx: SelectedTextContext(Text: "word", BundleID: "xxx",Editable: false)), ctx: SelectedTextContext(Text: "word", BundleID: "xxx",Editable: false))
}
