import SwiftUI
import Combine

struct ChatTextView: View {
    let ctx: ChatContext
    @ObservedObject var viewModel: MessageViewModel
    @EnvironmentObject var pinned: PinnedModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var task: Task<Void, Never>?
    @State private var hostWindow: NSWindow?
    @State private var isCollapsed = false
    @State private var expandedFrame: NSRect?
    @State private var isNearBottom = true
    @State private var shouldAutoFollowTranscript = true

    private let bottomAnchorID = "BOTTOM"

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                headerView
                Divider().opacity(0.6)
                transcriptView
                ChatInputView(viewModel: viewModel, onCancel: { task?.cancel() })
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
            }
            .frame(minWidth: 620, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
            .background(colorScheme == .dark ? Color(red: 0.105, green: 0.102, blue: 0.095) : Color(red: 0.996, green: 0.996, blue: 0.992))
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
            }
            .frame(width: isCollapsed ? expandedFrame?.width : nil, height: isCollapsed ? expandedFrame?.height : nil)
            .opacity(isCollapsed ? 0 : 1)
            .allowsHitTesting(!isCollapsed)
            .accessibilityHidden(isCollapsed)

            if isCollapsed {
                CollapsedBubble(isCollapsed: $isCollapsed, window: hostWindow)
                    .fixedSize()
            }
        }
        .frame(width: isCollapsed ? 52 : nil, height: isCollapsed ? 52 : nil, alignment: .topLeading)
        .background(ChatWindowStyleSync(isCollapsed: isCollapsed, expandedFrame: expandedFrame) { window in
            if hostWindow !== window { hostWindow = window }
        })
        .onChange(of: viewModel.inProgress) { _, inProgress in
            if inProgress {
                shouldAutoFollowTranscript = isNearBottom
            } else if isNearBottom {
                shouldAutoFollowTranscript = true
            }
        }
        .onAppear {
            task = Task { await viewModel.fetchMessages(ctx: ctx) }
        }
        .onDisappear { task?.cancel() }
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Chat")
                    .font(.headline)
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ctx.bundleID) {
                    Text(FileManager.default.displayName(atPath: url.path))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { pinned.pinned.toggle() } label: {
                Label(pinned.pinned ? "chat.unpin" : "chat.pin", systemImage: pinned.pinned ? "pin.fill" : "pin")
                    .labelStyle(.iconOnly)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(pinned.pinned ? Color.accentColor : .secondary)
                    .background(pinned.pinned ? Color.accentColor.opacity(0.08) : .clear, in: .rect(cornerRadius: 8))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help(pinned.pinned ? "chat.unpin" : "chat.pin")

            Button {
                expandedFrame = hostWindow?.frame
                isCollapsed = true
                pinned.pinned = true
            } label: {
                Label("chat.collapse", systemImage: "minus")
                    .labelStyle(.iconOnly)
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("chat.collapse")

            Button { hostWindow?.close() } label: {
                Label("chat.close", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("chat.close")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ChatTranscriptScrollObserver(isResponding: viewModel.inProgress, isNearBottom: $isNearBottom) {
                    shouldAutoFollowTranscript = $0
                }
                .frame(width: 0, height: 0)

                LazyVStack(alignment: .leading, spacing: 26) {
                    ChatContextView(ctx: ctx)
                    ForEach(viewModel.messages) { message in
                        MessageView(message: message)
                            .id(message.id)
                    }
                    Color.clear.frame(height: 1).id(bottomAnchorID)
                }
                .font(.system(size: 15))
                .frame(maxWidth: 760)
                .padding(.horizontal, 30)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if viewModel.messages.last?.role == .user { shouldAutoFollowTranscript = true }
                scrollToBottomIfNeeded(proxy, animated: true)
            }
            .onReceive(lastMessageChangePublisher) { _ in
                scrollToBottomIfNeeded(proxy, animated: false)
            }
            .overlay(alignment: .bottom) {
                if !isNearBottom {
                    Button {
                        shouldAutoFollowTranscript = true
                        scrollToBottomIfNeeded(proxy, animated: true)
                    } label: {
                        Label("chat.latest", systemImage: "arrow.down")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func scrollToBottomIfNeeded(_ proxy: ScrollViewProxy, animated: Bool) {
        guard shouldAutoFollowTranscript else { return }
        DispatchQueue.main.async {
            withAnimation(animated && !reduceMotion ? .easeOut(duration: 0.15) : nil) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        }
    }

    private var lastMessageChangePublisher: AnyPublisher<Void, Never> {
        guard let last = viewModel.messages.last else { return Empty().eraseToAnyPublisher() }
        return last.objectWillChange
            .throttle(for: .milliseconds(80), scheduler: RunLoop.main, latest: true)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}
