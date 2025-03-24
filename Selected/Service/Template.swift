//
//  Template.swift
//  Selected
//
//  Created by sake on 2024/7/7.
//

import Foundation
import Stencil

func parseJSONString(jsonString: String) -> [String: Any]? {
    guard let data = jsonString.data(using: .utf8) else {
        print("Failed to convert string to data.")
        return nil
    }

    guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
          let dictionary = jsonObject as? [String: Any] else {
        print("Failed to decode JSON.")
        return nil
    }

    return dictionary
}


func renderTemplate(templateString: String, json: String) -> String {
    if var dictionary = parseJSONString(jsonString: json) {
        dictionary["system"] =  ["language": getCurrentAppLanguage()]
        print("language \(getCurrentAppLanguage())")
        return renderTemplate(templateString: templateString, with: dictionary)
    }
    return ""
}

func renderTemplate(templateString: String, with context: [String: Any]) -> String {
    let environment = Environment(loader: nil, trimBehaviour: .all)
    do {
        let rendered = try environment.renderTemplate(string: templateString, context: context)
        return rendered
    } catch {
        print("Failed to render template: \(error)")
        return ""
    }
}

func renderChatContent(content: String, chatCtx: ChatContext, options: [String:String]? = [String:String]()) -> String {
    var ctx = [String:Any]()
    ctx["options"] = options
    ctx["selected"] = chatCtx

    return renderTemplate(templateString: content, with: ctx)
}
