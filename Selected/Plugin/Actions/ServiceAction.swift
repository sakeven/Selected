import Foundation
import AppKit

struct ServiceAction: Codable {
    var name: String

    init(name: String) {
        self.name = name
    }

    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            PerfomService(serviceName: self.name, text: ctx.Text)
        })
    }
}
