//
//  SpeakAction.swift
//  Selected
//
//  Created by sake on 2024/3/28.
//

import Foundation





class SpeackAction: Decodable {
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            speak(ctx.Text)
        })
    }
}
