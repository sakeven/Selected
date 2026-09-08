import SwiftUI

struct ChatTranscriptScrollObserver: NSViewRepresentable {
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
