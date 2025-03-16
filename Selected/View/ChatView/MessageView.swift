//
//  MessageView.swift
//  Selected
//
//  Created by sake on 2024/6/29.
//

import Foundation
import SwiftUI
import MarkdownUI
import Highlightr

struct MessageView: View {
    @ObservedObject var message: ResponseMessage

    @Environment(\.colorScheme) private var colorScheme


    @State private var rotation: Double = 0
    @State private var animationTimer: Timer? = nil

    var body: some View {
        VStack(alignment: .leading){
            HStack{
                Text(LocalizedStringKey(message.role.rawValue))
                    .foregroundStyle(.blue.gradient).font(.headline)
                if message.role == .assistant || message.role == .tool {
                    switch message.status {
                        case .initial:
                            Image(systemName: "arrow.clockwise").foregroundStyle(.gray)
                        case .updating:
                            Image(systemName: "arrow.2.circlepath")
                                .foregroundStyle(.orange)
                                .rotationEffect(.degrees(rotation))
                                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
                                .onAppear(){
                                    animationTimer?.invalidate() // Invalidate any existing timer
                                    animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
                                        rotation += 5
                                        if rotation >= 360 {
                                            rotation -= 360
                                        }
                                    }
                                }.onDisappear(){
                                    animationTimer?.invalidate()
                                }
                        case .finished:
                            Image(systemName: "checkmark.circle").foregroundStyle(.green)
                        default:
                            EmptyView()
                    }
                } else if message.role == .system && message.status == .failure {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
                Spacer()
                if message.role == .assistant {
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(message.message, forType: .string)
                    }, label: {
                        Image(systemName: "doc.on.clipboard.fill")
                    })
                    .foregroundColor(Color.white)
                    .cornerRadius(5)
                    Button {
                        Task {
                            await speak(MarkdownContent(message.message).renderPlainText(), view: false)
                        }
                    } label: {
                        Image(systemName: "play.circle")
                    }.foregroundColor(Color.white)
                        .cornerRadius(5)
                }
            }.frame(height: 20).padding(.trailing, 30.0)


            if message.role == .system {
                if message.status == .failure {
                    Text(message.message).foregroundStyle(.red)
                        .padding(.leading, 20.0)
                        .padding(.trailing, 40.0)
                        .padding(.top, 5)
                        .padding(.bottom, 20)
                } else {
                    Text(message.message)
                        .padding(.leading, 20.0)
                        .padding(.trailing, 40.0)
                        .padding(.top, 5)
                        .padding(.bottom, 20)
                }
            } else {
                MarkdownWithLateXView( markdownString: message.message)
                    .padding(.leading, 20.0)
                    .padding(.trailing, 40.0)
                    .padding(.top, 5)
                    .padding(.bottom, 20)
            }
        }.frame(width: 750)
    }

    private var codeTheme: CodeTheme {
        switch self.colorScheme {
            case .dark:
                return .dark
            default:
                return .light
        }
    }
}
