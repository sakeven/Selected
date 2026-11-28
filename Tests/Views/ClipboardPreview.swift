import AppKit
import SwiftUI
import WebKit
import XCTest
@testable import Selected

@MainActor
final class ClipboardPreviewTests: XCTestCase {
    func testReadingUsesRegularBodyTextThroughoutAndPreservesSelection() async throws {
        for text in ["周会行动清单👩🏽‍💻\r\n\r\n周四和编辑一起过稿。", "{\n  \"count\": 3\n}"] {
            let clip = try makeClipboardFixture(text: text, representations: [(.string, Data(text.utf8))])
            let host = NSHostingView(rootView: ClipTextPreview(data: clip))
            let window = show(host)
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(100))

            let view = try XCTUnwrap(descendant(NSTextView.self, in: host))
            let storage = try XCTUnwrap(view.textStorage)
            storage.enumerateAttribute(.font, in: NSRange(location: 0, length: storage.length)) { font, _, _ in
                XCTAssertEqual(font as? NSFont, NSFont.systemFont(ofSize: 15))
            }
            view.selectAll(nil)
            XCTAssertEqual((view.string as NSString).substring(with: view.selectedRange()), text)
            XCTAssertEqual(clip.primaryItem?.data, Data(text.utf8))
        }
    }

    func testRTFPreviewPreservesFormattingWhenPlainTextComesFirst() async throws {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = NSAttributedString(string: "富文本标题", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.red,
            .backgroundColor: NSColor.yellow,
            .paragraphStyle: paragraph
        ])
        let rtf = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let clip = try makeClipboardFixture(text: text.string, representations: [(.string, Data(text.string.utf8)), (.rtf, rtf)])
        let originalData = clip.getItems().map(\.data)
        let host = NSHostingView(rootView: ClipDataView(data: clip, onTogglePin: {}))
        let window = show(host)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))

        let readingView = try XCTUnwrap(descendant(NSTextView.self, in: host))
        let readingAttributes = try XCTUnwrap(readingView.textStorage?.attributes(at: 0, effectiveRange: nil))
        XCTAssertEqual(readingView.string, text.string)
        XCTAssertEqual((readingAttributes[.font] as? NSFont)?.pointSize, 15)
        XCTAssertNil(readingAttributes[.backgroundColor])

        let picker = try XCTUnwrap(descendant(NSSegmentedControl.self, in: host))
        XCTAssertEqual(picker.selectedSegment, 0)
        picker.selectedSegment = 1
        XCTAssertTrue(picker.sendAction(picker.action, to: picker.target))
        try await Task.sleep(for: .milliseconds(100))
        let view = try XCTUnwrap(descendant(NSTextView.self, in: host))
        let attributes = try XCTUnwrap(view.textStorage?.attributes(at: 0, effectiveRange: nil))
        let font = try XCTUnwrap(attributes[.font] as? NSFont)
        XCTAssertEqual(view.string, text.string)
        XCTAssertEqual(font.pointSize, 24)
        XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        XCTAssertEqual((attributes[.foregroundColor] as? NSColor)?.usingColorSpace(.deviceRGB)?.redComponent, 1)
        XCTAssertEqual((attributes[.backgroundColor] as? NSColor)?.usingColorSpace(.deviceRGB)?.greenComponent, 1)
        XCTAssertEqual((attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment, .center)
        XCTAssertFalse(view.isEditable)
        XCTAssertTrue(view.isSelectable)
        XCTAssertGreaterThan(view.bounds.width, 300)
        XCTAssertEqual(clip.getItems().map(\.data), originalData)

        picker.selectedSegment = 0
        XCTAssertTrue(picker.sendAction(picker.action, to: picker.target))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(descendant(NSTextView.self, in: host)?.textStorage?.attribute(.backgroundColor, at: 0, effectiveRange: nil))
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        ClipService(pasteboard: pasteboard).restore(clip) {}
        XCTAssertEqual(pasteboard.data(forType: .rtf), rtf)
        XCTAssertEqual(pasteboard.string(forType: .string), text.string)
    }

    func testRTFPreviewUpdatesWhenOnlyFormattingChanges() async throws {
        let first = NSAttributedString(string: "Same text", attributes: [.font: NSFont.systemFont(ofSize: 12)])
        let second = NSAttributedString(string: "Same text", attributes: [.font: NSFont.boldSystemFont(ofSize: 28)])
        let host = NSHostingView(rootView: RTFView(text: first))
        let window = show(host)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        let originalView = try XCTUnwrap(descendant(NSTextView.self, in: host))
        host.rootView = RTFView(text: second)
        try await Task.sleep(for: .milliseconds(100))
        let view = try XCTUnwrap(descendant(NSTextView.self, in: host))
        XCTAssertTrue(view === originalView)
        XCTAssertEqual((view.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 28)
    }

    func testHTMLPreviewRendersTableAndUpdatesSelection() async throws {
        let html = """
        <meta charset="utf-8"><table><tr><td style="color:rgb(255,0,0);font-size:24px;font-weight:700">网页表格</td></tr></table>
        <script>document.body.innerHTML = 'Script ran';</script>
        """
        let plainText = "  网页表格\n"
        let clip = try makeClipboardFixture(text: plainText, representations: [(.string, Data(plainText.utf8)), (.html, Data(html.utf8))])
        let host = NSHostingView(rootView: ClipTextPreview(data: clip))
        let window = show(host)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(descendant(WKWebView.self, in: host))
        let readingView = try XCTUnwrap(descendant(NSTextView.self, in: host))
        XCTAssertTrue(readingView.isSelectable)
        XCTAssertEqual(readingView.string, plainText)

        host.rootView = ClipTextPreview(data: clip, showsOriginalFormatting: true)
        try await Task.sleep(for: .milliseconds(100))
        let webView = try XCTUnwrap(descendant(WKWebView.self, in: host))
        try await waitForText("网页表格", in: webView)
        let values = try await webView.evaluateJavaScript("[document.querySelectorAll('table').length, getComputedStyle(document.querySelector('td')).fontSize, getComputedStyle(document.querySelector('td')).color]") as? [Any]
        XCTAssertEqual(values?[0] as? Int, 1)
        XCTAssertEqual(values?[1] as? String, "24px")
        XCTAssertEqual(values?[2] as? String, "rgb(255, 0, 0)")
        XCTAssertFalse(webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)
        XCTAssertEqual(clip.htmlData, Data(html.utf8))

        let next = try makeClipboardFixture(text: "下一条", representations: [(.html, Data("<p>下一条</p>".utf8))])
        host.rootView = ClipTextPreview(data: next, showsOriginalFormatting: true)
        try await waitForText("下一条", in: webView)
    }

    func testUnreadableRTFFallsBackToPlainText() async throws {
        let clip = try makeClipboardFixture(text: "可读的原文", representations: [(.rtf, Data("invalid rtf".utf8))])
        let host = NSHostingView(rootView: ClipTextPreview(data: clip, showsOriginalFormatting: true))
        let window = show(host)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(descendant(NSTextView.self, in: host)?.string, "可读的原文")
    }

    func testHTMLWithAppSourceRendersWithoutOpeningSourceURL() async throws {
        let html = "<p style='font-weight:700'>应用内复制的内容</p>"
        let clip = try makeClipboardFixture(text: "应用内复制的内容", representations: [(.html, Data(html.utf8))])
        clip.url = "app://-/index.html"
        let host = NSHostingView(rootView: ClipTextPreview(data: clip, showsOriginalFormatting: true))
        let window = show(host)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        let webView = try XCTUnwrap(descendant(WKWebView.self, in: host))
        try await waitForText("应用内复制的内容", in: webView)
        XCTAssertEqual(webView.url?.absoluteString, "about:blank")
        XCTAssertEqual(clip.url, "app://-/index.html")
        let weight = try await webView.evaluateJavaScript("getComputedStyle(document.querySelector('p')).fontWeight") as? String
        XCTAssertEqual(weight, "700")
    }

    func testFormattedClipsWithoutReadableTextShowTheirOriginalRepresentation() async throws {
        let html = Data("<table><tr><td>原表格</td></tr></table>".utf8)
        let clip = try makeClipboardFixture(text: nil, representations: [(.html, html)])
        let host = NSHostingView(rootView: ClipTextPreview(data: clip))
        let window = show(host)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        let webView = try XCTUnwrap(descendant(WKWebView.self, in: host))
        try await waitForText("原表格", in: webView)

        let text = NSAttributedString(string: "RTF")
        let rtf = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let next = try makeClipboardFixture(text: " \u{FFFC}\n", representations: [(.rtf, rtf)])
        host.rootView = ClipTextPreview(data: next)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(descendant(NSTextView.self, in: host)?.string, text.string)
    }

    func testHTMLCancelsExternalSchemeRedirectsAndFrames() async throws {
        let host = NSHostingView(rootView: HTMLView(htmlData: Data("<p>初始预览</p>".utf8), baseURL: nil))
        let window = show(host)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        let webView = try XCTUnwrap(descendant(WKWebView.self, in: host))
        try await waitForText("初始预览", in: webView)
        let coordinator = try XCTUnwrap(webView.navigationDelegate as? HTMLView.Coordinator)
        let recorder = NavigationRecorder(coordinator: coordinator)
        webView.navigationDelegate = recorder
        webView.loadHTMLString("""
        <meta http-equiv="refresh" content="0;url=app://-/index.html">
        <iframe src="app://-/embedded.html"></iframe>
        <p>仍然显示预览</p>
        """, baseURL: nil)
        for _ in 0..<100 {
            if recorder.cancelledMainFrames.contains(true) && recorder.cancelledMainFrames.contains(false) { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(recorder.cancelledMainFrames.contains(true), "The external redirect should be cancelled")
        XCTAssertTrue(recorder.cancelledMainFrames.contains(false), "The external frame should be cancelled")
        try await waitForText("仍然显示预览", in: webView)
        XCTAssertEqual(webView.url?.absoluteString, "about:blank")
    }

    func testHTMLKeepsWebSourceForRelativeLinks() async throws {
        let host = NSHostingView(rootView: HTMLView(
            htmlData: Data("<a href='details'>网页链接</a>".utf8),
            baseURL: URL(string: "https://example.test/articles/index.html")
        ))
        let window = show(host)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        let webView = try XCTUnwrap(descendant(WKWebView.self, in: host))
        try await waitForText("网页链接", in: webView)
        let href = try await webView.evaluateJavaScript("document.querySelector('a').href") as? String
        XCTAssertEqual(href, "https://example.test/articles/details")
    }

    private final class NavigationRecorder: NSObject, WKNavigationDelegate {
        let coordinator: HTMLView.Coordinator
        var cancelledMainFrames: [Bool] = []

        init(coordinator: HTMLView.Coordinator) {
            self.coordinator = coordinator
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            let policy = await coordinator.webView(webView, decidePolicyFor: navigationAction)
            if policy == .cancel, navigationAction.request.url?.scheme == "app" {
                cancelledMainFrames.append(navigationAction.targetFrame?.isMainFrame == true)
            }
            return policy
        }
    }

    private func show(_ view: NSView) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 350), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderFront(nil)
        view.layoutSubtreeIfNeeded()
        return window
    }

    private func descendant<T: NSView>(_ type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        return view.subviews.lazy.compactMap { self.descendant(type, in: $0) }.first
    }

    private func waitForText(_ text: String, in webView: WKWebView) async throws {
        for _ in 0..<100 {
            if let value = try? await webView.evaluateJavaScript("document.body.innerText") as? String,
               value.trimmingCharacters(in: .whitespacesAndNewlines) == text { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("HTML preview did not display \(text)")
    }
}
