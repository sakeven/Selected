//
//  SpeakAction.swift
//  Selected
//
//  Created by sake on 2024/3/28.
//

import Foundation
import SwiftUI

class SpeackAction: Decodable {
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(
            actionMeta: generic, complete: { ctx in
                // await speak(ctx.Text)
                speak(ctx.Text)
        })
    }
}
