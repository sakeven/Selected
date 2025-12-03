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

    var showSharingButton = true
    var onClick: (() -> Void)?

    @Environment(\.openURL) var openURL

    var body: some View {
        // spacing: 0， 让 button 紧邻，不要空隙
        HStack(spacing: 0){
            ForEach(actions) { action in
                BarButton(icon: action.actionMeta.icon, title: action.actionMeta.title , clicked: {
                    $isLoading in
                    if let onClick = onClick {
                        onClick()
                    }
                    isLoading = true
                    NSLog("ctx: \(ctx)")
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
            if showSharingButton{
                SharingButton(message: ctx.Text)
            }
            if let res = calculate(ctx.Text) {
                let v = valueFormatter.string(from: NSNumber(value: res))!
                NumerberView(value: v)
            }
        }.frame(height: 30)
            .padding(.leading, 10).padding(.trailing, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(5).fixedSize()
    }
}


struct NumerberView: View {
    @State var value: String
    @State private var isCopied = false // 用于控制动画效果

    var body: some View {
        Text(value)
            .fontWeight(.bold)
            .foregroundColor(isCopied ? .blue : .primary) // 颜色变化动画
            .onTapGesture {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(value, forType: .string)

                // 触发动画
                withAnimation(.easeInOut(duration: 0.1)) {
                    isCopied = true
                }

                // 动画结束后恢复默认状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isCopied = false
                    }
                }
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
