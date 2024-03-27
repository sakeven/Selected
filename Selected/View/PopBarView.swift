//
//  HoverBallView.swift
//  Selected
//
//  Created by sake on 2024/3/9.
//

import SwiftUI

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
                    NSLog("ctx: \(ctx)")
                    action.complete(ctx)
                })
            }
            SharingButton(message: ctx.Text)
        }.frame(height: 30)
            .padding(.leading, 10).padding(.trailing, 10)
            .background(.gray).cornerRadius(5)
    }
}

#Preview {
    PopBarView(actions: GetActions(ctx: SelectedTextContext(Text: "word", BundleID: "xxx",Editable: false)), ctx: SelectedTextContext(Text: "word", BundleID: "xxx",Editable: false))
}
