import Foundation
import AppKit

class MapAction {
    func supported(ctx: SelectedTextContext) -> Bool {
        return !ctx.Address.isEmpty
    }

    func generate(generic: GenericAction) -> PerformAction {
        let pa = PerformAction(
            actionMeta: generic, complete: { ctx in
                if let url = URL(string: "maps://?q="+ctx.Address) {
                    NSWorkspace.shared.open(url)
                }
            })
        pa.supported = supported
        return pa
    }
}
