//
//  BarButton.swift
//  Selected
//
//  Created by sake on 2024/3/11.
//

import SwiftUI

extension String {
    func trimPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}

struct BarButton: View {
    var icon: String
    var title: String
    var clicked: ((_: Binding<Bool>) -> Void) /// use closure for callback

    @State private var shouldPopover: Bool = false
    @State private var hoverWorkItem: DispatchWorkItem?

    @State private var isLoading = false


    var body: some View {
        Button {
            DispatchQueue.main.async {
                clicked($isLoading)
                NSLog("isLoading \(isLoading)")
            }
        } label: {
            ZStack {
                HStack{
                    Icon(icon)
                }.frame(width: 40, height: 30).opacity(isLoading ? 0.5 : 1)
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        .scaleEffect(0.5, anchor: .center) // 根据需要调整大小和位置
                }
            }
        }.frame(width: 40, height: 30)
            .buttonStyle(BarButtonStyle()).onHover(perform: { hovering in
                hoverWorkItem?.cancel()
                if title.count == 0 {
                    shouldPopover = false
                    return
                }
                if !hovering{
                    shouldPopover = false
                    return
                }
                
                let workItem = DispatchWorkItem {
                    shouldPopover = hovering
                }
                hoverWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
            })
            .popover(isPresented: $shouldPopover, content: {
                // 增加 interactiveDismissDisabled。
                // 否则有 popover 时，需要点击 action 使得 popover 消失然后再次点击才能产生 onclick 事件。
                Text(title).font(.headline).padding(5).interactiveDismissDisabled()
            })
    }
}

// BarButtonStyle: click、onHover 显示不同的颜色
struct BarButtonStyle: ButtonStyle {
    @State var isHover = false
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(getColor(isPressed: configuration.isPressed))
            .foregroundColor(colorScheme == .dark ? .white: .black )
            .onHover { hovering in
                isHover = hovering
            }
    }

    func getColor(isPressed: Bool) -> Color {
        if isPressed {
            return .blue.opacity(0.4)
        }
        return isHover ? .blue.opacity(0.25) : .clear
    }
}
