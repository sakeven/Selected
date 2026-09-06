import SwiftUI

struct BarButtonTooltip: NSViewRepresentable {
    let title: String
    let isPresented: Bool

    func makeNSView(context: Context) -> AnchorView {
        AnchorView()
    }

    func updateNSView(_ nsView: AnchorView, context: Context) {
        if isPresented {
            nsView.show(title)
        } else {
            nsView.hide()
        }
    }

    static func dismantleNSView(_ nsView: AnchorView, coordinator: ()) {
        nsView.hide()
    }

    final class AnchorView: NSView {
        private var panel: FloatingPanel?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func show(_ title: String) {
            guard panel == nil, let window, let screen = window.screen else { return }

            let label = Text(title)
                .font(.caption)
                .lineLimit(2)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: 260)
                .fixedSize()
                .background(.regularMaterial, in: .rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.primary.opacity(0.10), lineWidth: 0.5)
                }
                .accessibilityHidden(true)
            let content = NSHostingView(rootView: label)
            let size = content.fittingSize
            let anchor = window.convertToScreen(convert(bounds, to: nil))
            let visibleFrame = screen.visibleFrame
            let x = min(max(anchor.midX - size.width / 2, visibleFrame.minX), visibleFrame.maxX - size.width)
            let below = anchor.minY - size.height - 8
            let y = below >= visibleFrame.minY ? below : anchor.maxY + 8

            let panel = FloatingPanel(
                contentRect: NSRect(origin: NSPoint(x: x, y: y), size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.ignoresMouseEvents = true
            panel.appearance = window.effectiveAppearance
            panel.level = window.level
            panel.contentView = content
            window.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)
            self.panel = panel
        }

        func hide() {
            guard let panel else { return }
            panel.parent?.removeChildWindow(panel)
            panel.close()
            self.panel = nil
        }
    }
}
