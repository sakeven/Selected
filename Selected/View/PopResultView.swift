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
    var maximumHeight: CGFloat = 320
    @State private var isCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Measure the text at its reading width; only overflow needs scrolling.
            content
                .hidden()
                .frame(maxHeight: maximumHeight, alignment: .top)
                .overlay(alignment: .topLeading) {
                    ScrollView { content.textSelection(.enabled) }
                        .scrollBounceBehavior(.basedOnSize)
                }
            VStack(spacing: 6) {
                Button("Close", systemImage: "xmark") {
                    WindowManager.shared.closeAllWindows(.force)
                }
                .keyboardShortcut(.cancelAction)
                .help("Close")
                Button(isCopied ? "Copied" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc") {
                    copyText(text)
                    isCopied = true
                }
                .help("Copy")
                if editable {
                    Button("Replace original selection", systemImage: "return") {
                        WindowManager.shared.closeAllWindows(.force)
                        pasteText(text)
                    }
                    .help("Replace original selection")
                    Button("Insert before selection", systemImage: "arrow.uturn.left") {
                        WindowManager.shared.closeAllWindows(.force)
                        pasteTextBefore(text)
                    }
                    .help("Insert before selection")
                    Button("Insert after selection", systemImage: "arrow.uturn.right") {
                        WindowManager.shared.closeAllWindows(.force)
                        pasteTextAfter(text)
                    }
                    .help("Insert after selection")
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.10), lineWidth: 0.5)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var content: some View {
        Text(text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters)))
            .font(.body)
            .multilineTextAlignment(.leading)
            .frame(width: 360, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
