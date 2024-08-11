//
//  SpotlightView.swift
//  Selected
//
//  Created by sake on 2024/8/4.
//

import Foundation
import SwiftUI


struct SpotlightView: View {
    @State private var searchText: String = ""
    @State private var isFocused: Bool = false
    private var actions: [PerformAction]
    private var bundleIDOfFrontmostWindow: String

    init() {
        bundleIDOfFrontmostWindow = getBundleID()
        actions = GetActions(ctx: SelectedTextContext(Text: "", BundleID: bundleIDOfFrontmostWindow, Editable: false))
    }

    var body: some View {
        VStack {
            HStack {
                TextField("Spotlight", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
            }
            .background(Color.gray)
            .cornerRadius(10)

            if !searchText.isEmpty {
                PopBarView(actions: actions, ctx: SelectedTextContext(Text: searchText, BundleID: bundleIDOfFrontmostWindow, Editable: false),
                           onClick: {
                    SpotlightWindowManager.shared.forceCloseWindow()
                })
            }
        }.frame(width: 500)
            .onAppear {
                // Try to focus the TextField when the view appears
                DispatchQueue.main.async {
                    self.isFocused = true
                }
            }
    }
}


#Preview {
    SpotlightView()
}
