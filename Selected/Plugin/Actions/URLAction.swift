import Foundation
import AppKit

struct URLAction: Codable {
    var url: String

    init(url: String) {
        self.url = url
    }

    func generate(pluginInfo: PluginInfo, generic: GenericAction, popclip: PopClipAction? = nil) -> PerformAction {

        return PerformAction(
            actionMeta: generic, complete: { ctx in

                let options = pluginInfo.getOptionsValue()
                let urlString = popclip?.renderURL(self.url, context: ctx, options: PopClipAction.optionValues(pluginInfo, values: options), exactPhrase: NSEvent.modifierFlags.contains(.option))
                    ?? PluginTemplate.render(self.url, context: ctx, options: options, urlEncoded: true)
                guard let url = URL(string: urlString) else {
                    return
                }

                openActionURL(url, bundleID: ctx.BundleID)
            })
    }
}
