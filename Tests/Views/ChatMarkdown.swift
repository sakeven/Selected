import AppKit
import SwiftUI
import XCTest
@testable import Selected

@MainActor
final class ChatMarkdownTests: XCTestCase {
    func testRepeatedFormulasDuringStreamingAndResizing() async throws {
        let source = """
        ## 重复公式

        事件 $S$ 和事件 $S$ 相同，**加粗的 $S$** 也必须正常显示。

        $$P(S) = 0.5$$

        $$P(S) = 0.5$$

        | 事件 | 概率 |
        | --- | --- |
        | $S$ | 0.5 |
        | $S$ | 0.5 |

        ```swift
        let formula = "$S$"
        print(formula, formula)
        ```
        """
        let host = NSHostingView(rootView: ChatMarkdownView(markdown: ""))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFront(nil)
        defer { window.close() }

        // Exercise the real attachment layout, including incomplete streamed delimiters.
        for count in stride(from: 1, through: source.count, by: 17) {
            host.rootView = ChatMarkdownView(markdown: String(source.prefix(count)))
            try await Task.sleep(for: .milliseconds(30))
            host.layoutSubtreeIfNeeded()
        }
        host.rootView = ChatMarkdownView(markdown: source)
        for width in [560, 360, 720] {
            window.setContentSize(NSSize(width: width, height: 700))
            try await Task.sleep(for: .milliseconds(150))
            host.layoutSubtreeIfNeeded()
            XCTAssertTrue(host.fittingSize.height.isFinite)
            XCTAssertGreaterThan(host.fittingSize.height, 100)
        }
    }
}
