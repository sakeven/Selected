import Foundation
import AppKit
import Defaults

class WebSearchAction {
    @Default(.search) var searchURL

    init() {
    }

    func generate(generic: GenericAction) -> PerformAction {

        return PerformAction(
            actionMeta: generic, complete: { ctx in

                let urlString = replaceOptions(content: self.searchURL, selectedText: ctx.Text)

                let url = URL(string: urlString)!

                AppLogger.plugin.info("open \(urlString)")
                openActionURL(url, bundleID: ctx.BundleID)
            })
    }
}
