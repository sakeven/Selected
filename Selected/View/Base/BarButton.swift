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

    @State private var isHovering = false
    @State private var showTitle = false
    @State private var isLoading = false


    var body: some View {
        Button {
            isHovering = false
            showTitle = false
            DispatchQueue.main.async {
                clicked($isLoading)
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
            .buttonStyle(BarButtonStyle())
            .disabled(isLoading)
            .onHover { isHovering = $0 }
            .task(id: isHovering) {
                showTitle = false
                guard isHovering, !title.isEmpty, !isLoading else { return }
                do { try await Task.sleep(for: .milliseconds(600)) }
                catch { return }
                showTitle = true
            }
            .popover(isPresented: $showTitle) {
                Text(title).font(.headline).padding(5)
                    // Keep a visible tooltip from consuming the action's first click.
                    .interactiveDismissDisabled()
            }
            .onDisappear { isHovering = false; showTitle = false }
            .accessibilityLabel(title)
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
