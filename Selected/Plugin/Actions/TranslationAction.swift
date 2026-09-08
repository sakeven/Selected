import Foundation
import AppKit

class TranslationAction: Decodable {
    var target: String

    init(target: String) {
        self.target = target
    }

    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            WindowManager.shared.createTranslationWindow(withText: ctx.Text, to: self.target)
        })
    }
}
