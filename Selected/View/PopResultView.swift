//
//  PopResultView.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation
import SwiftUI

struct PopResultView: View {
    let text: String
    let editable: Bool

    var body: some View {
        HStack(alignment: .center){
            let showText = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))

            if showText.count < 100 && showText.split(whereSeparator: \.isNewline).count < 3 {
                Text(showText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 500)
            } else {
                ScrollView {
                    Text(showText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 500)
                }
            }

            if editable {
                Divider()
                VStack{
                    Button {
                        WindowManager.shared.closeAllWindows(.force)
                        pasteText(text)
                    } label: {
                        Image(systemName: "return").foregroundStyle(.black)
                    }
                    .background(Color.accentColor)
                    .cornerRadius(5)

                    Button {
                        WindowManager.shared.closeAllWindows(.force)
                        pasteTextBefore(text)
                    } label: {
                        Image(systemName: "arrow.uturn.left").foregroundStyle(.green)
                    }
                    Button {
                        WindowManager.shared.closeAllWindows(.force)
                        pasteTextAfter(text)
                    } label: {
                        Image(systemName: "arrow.uturn.right").foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(10)
        .frame(height: 100)
        .background(.ultraThinMaterial)
        .cornerRadius(5)
        .fixedSize()

    }
}
