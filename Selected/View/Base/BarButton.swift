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

    @State private var isLoading = false
    @State private var isHovering = false
    @State private var showTitle = false


    var body: some View {
        Button {
            isHovering = false
            showTitle = false
            DispatchQueue.main.async {
                clicked($isLoading)
            }
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Icon(icon)
                        .scaleEffect(0.85)
                }
            }
            .frame(width: 34, height: 32)
        }
            .buttonStyle(BarButtonStyle())
            .disabled(isLoading)
            .background(BarButtonTooltip(title: title, isPresented: showTitle))
            .onHover { hovering in
                isHovering = hovering
                if !hovering { showTitle = false }
            }
            .task(id: isHovering && !isLoading && !title.isEmpty) {
                showTitle = false
                guard isHovering, !isLoading, !title.isEmpty else { return }
                do { try await Task.sleep(for: .milliseconds(600)) }
                catch { return }
                showTitle = true
            }
            .onDisappear {
                isHovering = false
                showTitle = false
            }
            .accessibilityLabel(title)
            .accessibilityValue(isLoading ? Text("Loading…") : Text(""))
    }
}

struct BarButtonStyle: ButtonStyle {
    @State private var isHover = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled && (isHover || configuration.isPressed) ? Color.accentColor : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.18 : isHover ? 0.10 : 0) : 0))
            }
            .contentShape(.rect(cornerRadius: 8))
            .onHover { isHover = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHover)
    }
}
