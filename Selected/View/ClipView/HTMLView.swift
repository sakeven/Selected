import SwiftUI
import WebKit

struct HTMLView: NSViewRepresentable {
    let htmlData: Data
    let baseURL: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.addUserScript(WKUserScript(source: """
            for (const element of [document.documentElement, document.body]) {
                element.style.setProperty('background', 'transparent', 'important');
                element.style.setProperty('color', 'CanvasText', 'important');
                element.style.setProperty('color-scheme', 'light dark', 'important');
            }
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
        let webView = WKWebView(frame: .zero, configuration: configuration)
        // The macOS web view also paints a canvas behind the HTML document.
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.appearance = NSAppearance(named: context.environment.colorScheme == .dark ? .darkAqua : .aqua)
        guard context.coordinator.htmlData != htmlData || context.coordinator.baseURL != baseURL else { return }
        context.coordinator.htmlData = htmlData
        context.coordinator.baseURL = baseURL
        let documentURL: URL
        if let baseURL, ["http", "https"].contains(baseURL.scheme?.lowercased() ?? "") {
            documentURL = baseURL
        } else {
            documentURL = URL(string: "about:blank")!
        }
        nsView.load(htmlData, mimeType: "text/html", characterEncodingName: "UTF-8", baseURL: documentURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var htmlData: Data?
        var baseURL: URL?

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let scheme = navigationAction.request.url?.scheme,
                  WKWebView.handlesURLScheme(scheme) else { return .cancel }
            return .allow
        }
    }
}
