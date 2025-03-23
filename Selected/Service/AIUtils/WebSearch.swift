//
//  WebSearch.swift
//  Selected
//
//  Created by sake on 23/3/25.
//

import Defaults
import OpenAI
import Foundation

public extension Model {
    static let gpt_4o_search_preview = "gpt-4o-search-preview"
    static let gpt_4o_mini_search_preview = "gpt-4o-mini-search-preview"

}

let webSearchDef = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
    name: "Web-Search",
    description: """
    If there is anything you are not clear about or do not understand, use this tool to search online. This tool is based on the gpt-4o-search-preview model. Please use the prompt text to request this tool to search for relevant.
    """,
    parameters: .init(type: .object, properties:[
        "text": .init(type: .string, description: "the text to search")
    ])
)

public class WebSearch {
    public static func search(_ text: String) async -> String {
        let configuration = OpenAI.Configuration(token: Defaults[.openAIAPIKey],
                                                 host: Defaults[.openAIAPIHost],
                                                 timeoutInterval: 60.0)
        let openAI = OpenAI(configuration: configuration)
        let model = Model.gpt_4o_mini_search_preview

        let query = ChatQuery(
            messages: [.init(role: .user, content: text)!],
            model: model)
        do {
            let result = try await openAI.chats(query: query)
            return result.choices[0].message.content!
        } catch {
            NSLog("webSearch error: \(error)")
            return ""
        }
    }

}
