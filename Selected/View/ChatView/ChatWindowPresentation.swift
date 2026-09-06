import SwiftUI

private struct FocusEffectDisabler: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled(true)
        } else {
            content
        }
    }
}

struct ChatWindowStyleSync: NSViewRepresentable {
    let isCollapsed: Bool
    let expandedFrame: NSRect?
    let onWindowResolved: (NSWindow) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            onWindowResolved(window)
            context.coordinator.apply(to: window, isCollapsed: isCollapsed, expandedFrame: expandedFrame)
        }
    }

    final class Coordinator {
        private var lastCollapsed: Bool?

        func apply(to window: NSWindow, isCollapsed: Bool, expandedFrame: NSRect?) {
            if !isCollapsed {
                window.styleMask = [.borderless, .nonactivatingPanel, .resizable]
                window.contentMinSize = NSSize(width: 620, height: 520)
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = false
                window.isMovableByWindowBackground = true

                if let expandedFrame, lastCollapsed == true {
                    window.setFrame(expandedFrame, display: true)
                }

                lastCollapsed = false
                return
            }

            window.styleMask = [.borderless, .nonactivatingPanel]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isMovableByWindowBackground = false
            window.contentMinSize = .zero
            window.setContentSize(NSSize(width: 52, height: 52))

            lastCollapsed = true
        }
    }
}

struct CollapsedBubble: View {
    @Binding var isCollapsed: Bool
    let window: NSWindow?

    @State private var dragStartOrigin: CGPoint?
    @State private var dragStartMouseLocation: CGPoint?
    @State private var didDragDuringGesture = false
    @State private var suppressExpand = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 18, y: 10)

            Button {
                guard !suppressExpand else { return }
                withAnimation { isCollapsed = false }
            } label: {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 52)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("chat.expand"))
            .help("chat.expand")
            .focusable(false)
            .modifier(FocusEffectDisabler())
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .contentShape(Circle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in
                    guard let window else { return }

                    if dragStartOrigin == nil {
                        dragStartOrigin = window.frame.origin
                        dragStartMouseLocation = NSEvent.mouseLocation
                        didDragDuringGesture = false
                    }

                    guard let dragStartOrigin, let dragStartMouseLocation else { return }
                    let currentMouseLocation = NSEvent.mouseLocation
                    let dx = currentMouseLocation.x - dragStartMouseLocation.x
                    let dy = currentMouseLocation.y - dragStartMouseLocation.y
                    if !didDragDuringGesture {
                        didDragDuringGesture = hypot(dx, dy) > 4
                    }
                    window.setFrameOrigin(.init(
                        x: dragStartOrigin.x + dx,
                        y: dragStartOrigin.y + dy
                    ))
                }
                .onEnded { _ in
                    if didDragDuringGesture {
                        suppressExpand = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            suppressExpand = false
                        }
                    }
                    dragStartOrigin = nil
                    dragStartMouseLocation = nil
                    didDragDuringGesture = false
                }
        )
    }
}
