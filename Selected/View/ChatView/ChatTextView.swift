//
//  ChatTextView.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation
import SwiftUI
import MarkdownUI


struct ChatTextView: View {
    var text: String
    var options: [String: String]
    @ObservedObject var viewModel: MessageViewModel
    @State private var hasRep = false

    var body: some View {
        VStack(alignment: .leading) {
            List($viewModel.messages) { $message in
                MessageView(message: message)
            }.scrollContentBackground(.hidden)
                .listStyle(.inset)
                .frame(width: 550, height: 400).task {
                    await viewModel.fetchMessages(content: text, options: options)
                }
        }
    }
}
