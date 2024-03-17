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

    @Environment(\.openURL) var openURL

    var body: some View {
        // spacing: 0， 让 button 紧邻，不要空隙
        HStack(spacing: 0){
            ForEach(actions) { pluginInfo in
                BarButton(icon: pluginInfo.actionMeta.icon, clicked: {
                    pluginInfo.complete(ctx)
                    })
            }
        }.frame(height: 30)
            .padding(.leading, 10).padding(.trailing, 10)
            .background(.gray).cornerRadius(5)
    }
}

#Preview {
    PopBarView(actions: GetActions(ctx: SelectedTextContext(Text: "word", BundleID: "xxx",Editable: false)), ctx: SelectedTextContext(Text: "word", BundleID: "xxx",Editable: false))
}
