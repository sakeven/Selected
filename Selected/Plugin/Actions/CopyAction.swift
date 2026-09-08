import Foundation
import AppKit

class CopyAction: Decodable{
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            NSPasteboard.general.declareTypes([.string], owner: nil)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(ctx.Text, forType: .string)
        })
    }
}
