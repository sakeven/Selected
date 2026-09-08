import AppKit
import CoreData
import SwiftUI
import WebKit
import XCTest
@testable import Selected

@MainActor
final class ClipboardPreviewTests: XCTestCase {
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
        let clip = try makeClip(text: text.string, representations: [(.string, Data(text.string.utf8)), (.rtf, rtf)])
        let originalData = clip.getItems().map(\.data)
        let host = NSHostingView(rootView: ClipTextPreview(data: clip))
        let window = show(host)
        defer { window.close() }
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
        let clip = try makeClip(text: "网页表格", representations: [(.string, Data("网页表格".utf8)), (.html, Data(html.utf8))])
        let host = NSHostingView(rootView: ClipTextPreview(data: clip))
        let window = show(host)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        let webView = try XCTUnwrap(descendant(WKWebView.self, in: host))
        try await waitForText("网页表格", in: webView)
        let values = try await webView.evaluateJavaScript("[document.querySelectorAll('table').length, getComputedStyle(document.querySelector('td')).fontSize, getComputedStyle(document.querySelector('td')).color]") as? [Any]
        XCTAssertEqual(values?[0] as? Int, 1)
        XCTAssertEqual(values?[1] as? String, "24px")
        XCTAssertEqual(values?[2] as? String, "rgb(255, 0, 0)")
        XCTAssertFalse(webView.configuration.defaultWebpagePreferences.allowsContentJavaScript)

        let next = try makeClip(text: "下一条", representations: [(.html, Data("<p>下一条</p>".utf8))])
        host.rootView = ClipTextPreview(data: next)
        try await waitForText("下一条", in: webView)
    }

    func testUnreadableRTFFallsBackToPlainText() async throws {
        let clip = try makeClip(text: "可读的原文", representations: [(.rtf, Data("invalid rtf".utf8))])
        let host = NSHostingView(rootView: ClipTextPreview(data: clip))
        let window = show(host)
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(descendant(NSTextView.self, in: host)?.string, "可读的原文")
    }

    func testHTMLWithAppSourceRendersWithoutOpeningSourceURL() async throws {
        let html = "<p style='font-weight:700'>应用内复制的内容</p>"
        let clip = try makeClip(text: "应用内复制的内容", representations: [(.html, Data(html.utf8))])
        clip.url = "app://-/index.html"
        let host = NSHostingView(rootView: ClipTextPreview(data: clip))
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

    private func makeClip(text: String, representations: [(NSPasteboard.PasteboardType, Data)]) throws -> ClipHistoryData {
        let model = try XCTUnwrap(NSManagedObjectModel.mergedModel(from: [Bundle.main]))
        let clip = ClipHistoryData(entity: try XCTUnwrap(model.entitiesByName["ClipHistoryData"]), insertInto: nil)
        clip.plainText = text
        for (type, data) in representations {
            let item = ClipHistoryItem(entity: try XCTUnwrap(model.entitiesByName["ClipHistoryItem"]), insertInto: nil)
            item.type = type.rawValue
            item.data = data
            clip.addToItems(item)
        }
        return clip
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
