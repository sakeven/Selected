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
                        ActionRequest.plugin(plugin, definition).perform(input: ActionInput(context: ctx), target: target)
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


struct NumerberView: View {
    let value: String
    @State private var isCopied = false

    var body: some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(value, forType: .string)
            isCopied = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCopied ? "checkmark" : "equal")
                    .frame(width: 12)
                    .accessibilityHidden(true)
                Text(value).monospacedDigit()
            }
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 8)
            .frame(height: 32)
        }
        .buttonStyle(BarButtonStyle())
        .help("Copy result")
        .accessibilityLabel(Text("Copy result") + Text(": ") + Text(value))
        .accessibilityValue(isCopied ? Text("Copied") : Text(value))
        .task(id: isCopied) {
            guard isCopied else { return }
            do { try await Task.sleep(for: .milliseconds(800)) }
            catch { return }
            isCopied = false
        }
    }
}

func calculate(_ equation: String) -> Double? {
    // if equation can pasre as a double number, the equation must be single number but not an equation.
    let d = Double(equation.trimmingCharacters(in: .init(charactersIn: " \n")))
    if d != nil {
        // return nil to avoid displaying the single number.
        return nil
    }
    // it will still return 30 if the equation is somewhat like `(30)`.
    return try? equation.evaluate()
}


#Preview {
    PopBarView(actions: GetActions(ctx: SelectedTextContext(Text: "word", BundleID: "xxx",Editable: false)), ctx: SelectedTextContext(Text: "word", BundleID: "xxx",Editable: false))
}
