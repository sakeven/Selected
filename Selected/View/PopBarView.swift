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
    
    @State private var isSharePresented = false

    
    @Environment(\.openURL) var openURL
    
    var body: some View {
        // spacing: 0， 让 button 紧邻，不要空隙
        HStack(spacing: 0){
            ForEach(actions) { action in
                BarButton(icon: action.actionMeta.icon, title: action.actionMeta.title , clicked: {
                    $isLoading in
                    isLoading = true
                    NSLog("ctx: \(ctx)")
                    if let complete =  action.complete {
                        complete(ctx)
                        isLoading = false
                    }
                    if let complete =  action.completeAsync {
                        Task {
                            await complete(ctx)
                            isLoading = false
                        }
                    }
                   
                    NSLog("end")
                })
            }
            SharingButton(message: ctx.Text)
            if let res = calculate(ctx.Text) {
                let v = valueFormatter.string(from: NSNumber(value: res))!
                Text(v).fontWeight(.bold).frame(height: 30).frame(width: 10*CGFloat(v.count))
            }
        }.frame(height: 30)
            .padding(.leading, 10).padding(.trailing, 10)
            .background(.gray).cornerRadius(5)
    }
}

func calculate(_ equation: String) -> Double? {
    try? equation.evaluate()
}

private var valueFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    return formatter
}()

#Preview {
    PopBarView(actions: GetActions(ctx: SelectedTextContext(Text: "word", BundleID: "xxx",Editable: false)), ctx: SelectedTextContext(Text: "word", BundleID: "xxx",Editable: false))
}
