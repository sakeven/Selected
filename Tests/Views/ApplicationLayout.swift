import AppKit
import SwiftUI
import XCTest
@testable import Selected

@MainActor
final class ApplicationLayoutTests: XCTestCase {
    func testApplicationScreensInLightAndDarkAppearance() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("layout-plugins-\(UUID())")
        let manager = PluginManager(extensionsDir: folder, hostVersion: "1.0.0")
        let context = ChatContext(text: "Original text 原始内容", webPageURL: "https://example.com", bundleID: "selected.tests.unknown-app")
        let user = ResponseMessage(message: "请解释这段内容。", files: [AIFileAttachment(filename: "notes.txt", data: Data("fixture".utf8), mimeType: "text/plain")], role: .user, status: .finished)
        let response = ResponseMessage(message: "**重点。**后续\n\n- First item\n- 第二项\n\n`code` and [link](https://example.com)", role: .assistant, status: .finished)
        response.summary = "推理内容"
        response.tools["search"] = AIToolCall(name: "Search", ret: "Completed", status: .success, arguments: "{}", command: nil, workdir: nil, sourceLinks: [.init(title: "Source", url: "https://example.com")])
        let failure = ResponseMessage(message: "请求失败，请重试。", role: .system, status: .failure)
        var plugin = Plugin.new()
        plugin.info.identifier = "test.layout"
        plugin.info.name = "Fixture Plugin"
        let session = PluginEditorSession(plugin: plugin, existing: nil)
        let screens: [(String, NSSize, () -> AnyView)] = [
            ("chat", NSSize(width: 780, height: 720), { AnyView(ChatTextView(ctx: context, viewModel: MessageViewModel(chatService: LayoutAIProvider())).environmentObject(PinnedModel())) }),
            ("composer", NSSize(width: 700, height: 180), { AnyView(ChatInputView(viewModel: MessageViewModel(chatService: LayoutAIProvider()))) }),
            ("assistant", NSSize(width: 700, height: 400), { AnyView(MessageView(message: response)) }),
            ("user", NSSize(width: 700, height: 180), { AnyView(MessageView(message: user)) }),
            ("failure", NSSize(width: 700, height: 160), { AnyView(MessageView(message: failure)) }),
            ("spotlight", NSSize(width: 520, height: 108), { AnyView(SpotlightView(target: ActionTarget(application: nil), bundleID: "", allActions: [])) }),
            ("popbar", NSSize(width: 280, height: 60), { AnyView(PopBarView(actions: [], ctx: SelectedTextContext(Text: "1 + 2"), showSharingButton: false)) }),
            ("plugin-editor", NSSize(width: 900, height: 760), { AnyView(PluginEditorView(session: session, manager: manager, didSave: { _ in })) })
        ]
        for (name, size, view) in screens {
            for scheme in [ColorScheme.light, .dark] {
                let host = NSHostingView(rootView: view().frame(width: size.width, height: size.height)
                    .environment(\.colorScheme, scheme)
                    .environment(\.locale, Locale(identifier: "en_US")))
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
                window.contentView = host
                window.orderFront(nil)
                try await Task.sleep(for: .milliseconds(300))
                host.layoutSubtreeIfNeeded()
                XCTAssertEqual(host.bounds.size, size)
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let image = NSImage(size: size)
                image.addRepresentation(bitmap)
                let attachment = XCTAttachment(image: image)
                let snapshotName = "application-\(name)-\(scheme == .light ? "light" : "dark")"
                attachment.name = snapshotName
                attachment.lifetime = .keepAlways
                add(attachment)
                try assertSnapshot(bitmap, named: snapshotName)
                window.close()
            }
        }
    }
}

private final class LayoutAIProvider: AIProvider {
    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.begin("fixture"))
            continuation.yield(.textDone("**重点。**后续保持原样。"))
            continuation.yield(.done)
            continuation.finish()
        }
    }
    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, Error> { chatOnce(selectedText: ctx.text) }
    func chatFollow(userMessage: UserMessage) -> AsyncThrowingStream<AIStreamEvent, Error> { chatOnce(selectedText: userMessage.text) }
}
