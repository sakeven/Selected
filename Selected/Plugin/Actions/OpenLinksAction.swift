import Foundation
import AppKit

class OpenLinksAction: Decodable {
    func supported(ctx: SelectedTextContext) -> Bool {
        return !ctx.URLs.isEmpty
    }

    func generate(generic: GenericAction) -> PerformAction {
        let pa = PerformAction(
            actionMeta: generic, complete: { ctx in
                NSLog("should open \(ctx.URLs)")

                for urlString in ctx.URLs {
                    NSLog("open \(urlString)")
                    guard var url = URL(string: urlString) else {
                        continue
                    }

                    if url.scheme == nil || url.scheme == "" {
                        url = url.setScheme("https")
                    }

                    DispatchQueue.main.async {
                        openActionURL(url, bundleID: ctx.BundleID)
                    }
                }
            })
        pa.supported = supported
        return pa
    }
}
