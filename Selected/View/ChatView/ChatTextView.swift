//
//  ChatTextView.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation
import SwiftUI
import MarkdownUI
import Defaults
import Combine

struct ChatTextView: View {
    let ctx: ChatContext

    @ObservedObject var viewModel: MessageViewModel
    @EnvironmentObject var pinned: PinnedModel
    @State private var task: Task<Void, Never>? = nil
    @State private var hostWindow: NSWindow?
    @State private var isCollapsed = false
    @State private var isNearBottom = true
    @State private var shouldAutoFollowTranscript = true

    private let bottomAnchorID = "BOTTOM"

    var body: some View {
        Group {
            if isCollapsed {
                CollapsedBubble(isCollapsed: $isCollapsed, window: hostWindow)
                    .fixedSize()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    headerView
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    transcriptView

                    Spacer(minLength: 0)

                    ChatInputView(viewModel: viewModel, onCancel: {
                        task?.cancel()
                    })
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
                    .frame(minHeight: 650)
                    .frame(width: 750,  alignment: .top)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.97))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(.rect(cornerRadius: 26))

            }
        }
        .background(ChatWindowStyleSync(isCollapsed: isCollapsed) { window in
            if hostWindow !== window {
                hostWindow = window
            }
        })
        .onChange(of: viewModel.inProgress) { _, inProgress in
            if inProgress {
                shouldAutoFollowTranscript = isNearBottom
            } else if isNearBottom {
                shouldAutoFollowTranscript = true
            }
        }
        .onAppear {
            task = Task{
                await viewModel.fetchMessages(ctx: ctx)
            }
        }
        .onDisappear(){
            task?.cancel()
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if ctx.bundleID != "" {
                    HStack(spacing: 10) {
                        getIcon(ctx.bundleID)
                        Text(getAppName(ctx.bundleID))
                            .font(.headline)
                    }
                }

                Spacer(minLength: 0)

                headerPillButton(
                    title: pinned.pinned ? String(localized: "chat.unpin") : String(localized: "chat.pin"),
                    systemImage: pinned.pinned ? "pin.slash" : "pin",
                    tint: .secondary
                ) {
                    pinned.pinned.toggle()
                }

                headerIconButton(systemImage: "minus") {
                    withAnimation {
                        isCollapsed = true
                        pinned.pinned = true
                    }
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "text.quote")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                Text(ctx.text.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.custom("UbuntuMonoNFM", size: 15))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .copyable([ctx.text])
                    .textSelection(.enabled)

                if ctx.webPageURL != "", let url = URL(string: ctx.webPageURL) {
                    Link(destination: url) {
                        Image(systemName: "globe")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(Color.accentColor.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }

    private var transcriptView: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                ChatTranscriptScrollObserver(
                    isResponding: viewModel.inProgress,
                    isNearBottom: $isNearBottom
                ) { shouldFollow in
                    shouldAutoFollowTranscript = shouldFollow
                }
                .frame(width: 0, height: 0)

                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageView(message: message)
                            .id(message.id)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottomIfNeeded(scrollViewProxy, animated: true)
            }
            .onReceive(lastMessageChangePublisher) { _ in
                scrollToBottomIfNeeded(scrollViewProxy, animated: false)
            }
        }
        .frame(height: 400)
        .padding(.horizontal, 16)
    }

    private func getAppName(_ bundleID: String) -> String {
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
        return FileManager.default.displayName(atPath: bundleURL.path)
    }

    private func getIcon(_ bundleID: String) -> some View {
        let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)!
        return AnyView(
            Image(nsImage: NSWorkspace.shared.icon(forFile: bundleURL.path)).resizable().aspectRatio(contentMode: .fit).frame(width: 30, height: 30)
        )
    }

    private func scrollToBottomIfNeeded(_ proxy: ScrollViewProxy, animated: Bool) {
        guard shouldAutoFollowTranscript else { return }

        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        }
    }

    private var lastMessageChangePublisher: AnyPublisher<Void, Never> {
        guard let last = viewModel.messages.last else {
            return Empty().eraseToAnyPublisher()
        }
        return last.objectWillChange
            .throttle(for: .milliseconds(80), scheduler: RunLoop.main, latest: true)
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    private func headerPillButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.88))
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func headerIconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.88), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct ChatTranscriptScrollObserver: NSViewRepresentable {
    let isResponding: Bool
    @Binding var isNearBottom: Bool
    let onAutoFollowStateChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isResponding: isResponding,
            isNearBottom: $isNearBottom,
            onAutoFollowStateChange: onAutoFollowStateChange
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attachIfNeeded(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isResponding = isResponding
        context.coordinator.onAutoFollowStateChange = onAutoFollowStateChange
        context.coordinator.attachIfNeeded(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private let isNearBottom: Binding<Bool>
        var isResponding: Bool
        var onAutoFollowStateChange: (Bool) -> Void
        private weak var scrollView: NSScrollView?
        private var observer: NSObjectProtocol?
        private var liveScrollStartObserver: NSObjectProtocol?
        private var liveScrollEndObserver: NSObjectProtocol?
        private var isUserScrolling = false
        private let threshold: CGFloat = 24

        init(
            isResponding: Bool,
            isNearBottom: Binding<Bool>,
            onAutoFollowStateChange: @escaping (Bool) -> Void
        ) {
            self.isResponding = isResponding
            self.isNearBottom = isNearBottom
            self.onAutoFollowStateChange = onAutoFollowStateChange
        }

        func attachIfNeeded(to view: NSView) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                guard let scrollView = self.findScrollView(from: view) else { return }
                guard self.scrollView !== scrollView else { return }

                self.detach()
                self.scrollView = scrollView
                scrollView.contentView.postsBoundsChangedNotifications = true
                self.observer = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: scrollView.contentView,
                    queue: .main
                ) { [weak self] _ in
                    self?.handleScrollChange()
                }
                self.liveScrollStartObserver = NotificationCenter.default.addObserver(
                    forName: NSScrollView.willStartLiveScrollNotification,
                    object: scrollView,
                    queue: .main
                ) { [weak self] _ in
                    self?.isUserScrolling = true
                }
                self.liveScrollEndObserver = NotificationCenter.default.addObserver(
                    forName: NSScrollView.didEndLiveScrollNotification,
                    object: scrollView,
                    queue: .main
                ) { [weak self] _ in
                    self?.isUserScrolling = false
                    self?.handleScrollChange()
                }
                self.handleScrollChange()
            }
        }

        func detach() {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            if let liveScrollStartObserver {
                NotificationCenter.default.removeObserver(liveScrollStartObserver)
            }
            if let liveScrollEndObserver {
                NotificationCenter.default.removeObserver(liveScrollEndObserver)
            }
            observer = nil
            liveScrollStartObserver = nil
            liveScrollEndObserver = nil
            isUserScrolling = false
            scrollView = nil
        }

        private func handleScrollChange() {
            let nearBottom = updateIsNearBottom()
            guard isResponding, isUserScrolling else { return }
            onAutoFollowStateChange(nearBottom)
        }

        @discardableResult
        private func updateIsNearBottom() -> Bool {
            guard let scrollView, let documentView = scrollView.documentView else {
                return true
            }
            let distanceToBottom = documentView.bounds.maxY - scrollView.contentView.bounds.maxY
            let nearBottom = distanceToBottom <= threshold
            if isNearBottom.wrappedValue != nearBottom {
                isNearBottom.wrappedValue = nearBottom
            }
            return nearBottom
        }

        private func findScrollView(from view: NSView) -> NSScrollView? {
            if let scrollView = view.enclosingScrollView {
                return scrollView
            }

            var candidate: NSView? = view
            while let currentView = candidate {
                if let scrollView = currentView as? NSScrollView {
                    return scrollView
                }
                if let scrollView = currentView.enclosingScrollView {
                    return scrollView
                }
                candidate = currentView.superview
            }
            return nil
        }
    }
}
private struct FocusEffectDisabler: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled(true)
        } else {
            content
        }
    }
}

private struct ChatWindowStyleSync: NSViewRepresentable {
    let isCollapsed: Bool
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
            context.coordinator.apply(to: window, isCollapsed: isCollapsed)
        }
    }

    final class Coordinator {
        private var lastCollapsed: Bool?
        private var expandedFrame: NSRect?

        func apply(to window: NSWindow, isCollapsed: Bool) {
            if lastCollapsed == nil {
                expandedFrame = window.frame
            }

            if !isCollapsed {
                window.styleMask = [.borderless, .nonactivatingPanel]
                window.isOpaque = false
                window.backgroundColor = .clear
                window.hasShadow = false
                window.isMovableByWindowBackground = true

                if let expandedFrame, lastCollapsed == true {
                    window.setFrame(expandedFrame, display: true)
                } else {
                    expandedFrame = window.frame
                }

                lastCollapsed = false
                return
            }

            if lastCollapsed != true {
                expandedFrame = window.frame
            }

            window.styleMask = [.borderless, .nonactivatingPanel]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isMovableByWindowBackground = false
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
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
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
