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
    var clicked: (() -> Void) /// use closure for callback
    
    
    var body: some View {
        Button {
            clicked()
        } label: {
            if icon.starts(with: "file://") {
                // load from a file
                HStack{
                    Image(nsImage: NSImage(contentsOfFile: icon.trimPrefix("file://"))!).resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30).frame(height: 30)
                }  .frame(width: 40).frame(height: 30)
            } else {
                HStack{
                    Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20).frame(height: 20)
                }.frame(width: 40).frame(height: 30)
            }
        }.frame(width: 40).frame(height: 30)
        .buttonStyle(BarButtonStyle())
    }
}

// BarButtonStyle: click、onHover 显示不同的颜色
struct BarButtonStyle: ButtonStyle {
    @State var isHover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(getColor(isPressed: configuration.isPressed))
            .foregroundColor(.white)
            .onHover(perform: { hovering in
                isHover = hovering
            })
    }
    
    func getColor(isPressed: Bool) -> Color{
        if isPressed {
            return .blue.opacity(0.4)
        }
        return isHover ? .blue : .gray
    }
}
