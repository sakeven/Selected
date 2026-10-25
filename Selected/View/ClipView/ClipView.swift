//
//  ClipView.swift
//  Selected
//
//  Created by sake on 2024/4/7.
//

import AppKit
import CoreData
import Defaults
import Foundation
import PDFKit
import SwiftUI

struct ClipView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ClipHistoryData.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: false)
        ],
        animation: .default
    )
    private var clips: FetchedResults<ClipHistoryData>

    @ObservedObject var viewModel = ClipViewModel.shared
    @State private var isFocused = true

    @State private var searchText = ""
    @State private var localSelection: ClipHistoryData?
    @State private var aiRequest: ClipAIPromptView.Request?

    private var filteredClips: [ClipHistoryData] {
        if searchText.isEmpty {
            return Array(clips)
        }

        return clips.filter { $0.matchesSearch(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "clipboard")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.selection, in: .rect(cornerRadius: 11))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clipboard").font(.title2.weight(.semibold))
                    Text("clip.workspace.subtitle").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close", systemImage: "xmark") {
                    ClipWindowManager.shared.forceCloseWindow()
                }
                .buttonStyle(AppIconButtonStyle())
                .help("clip.dismiss.shortcut")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(AppTheme.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 300)

                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 1)

                detailPane
                    .frame(minWidth: 500)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            HStack(spacing: 16) {
                ShortcutHint(keys: "↑ ↓", title: "clip.navigate")
                Button {
                    ClipWindowManager.shared.forceCloseWindow()
                } label: {
                    ShortcutHint(keys: "esc", title: "clip.dismiss")
                }
                .buttonStyle(.plain)
                .help("clip.dismiss.shortcut")
                Spacer()

                if let selected = localSelection {
                    Button("clip.copy.short", systemImage: "doc.on.doc") {
                        ClipWindowManager.shared.restore(selected, paste: false)
                    }
                    .buttonStyle(AppButtonStyle())
                    .help("clip.copy")

                    HStack(spacing: 4) {
                        Button {
                            ClipWindowManager.shared.restore(selected, paste: true)
                        } label: {
                            HStack(spacing: 16) {
                                Text("clip.paste")
                                Image(systemName: "return").accessibilityHidden(true)
                            }
                        }
                        if let text = selected.plainText {
                            Menu {
                                Button("Paste plain text") {
                                    ClipWindowManager.shared.forceCloseWindow()
                                    pasteText(text)
                                }
                            } label: {
                                Label("clip.pasteOptions", systemImage: "chevron.down")
                            }
                            .labelStyle(.iconOnly)
                            .menuStyle(.button)
                            .menuIndicator(.hidden)
                            .help("clip.pasteOptions")
                        }
                    }
                    .buttonStyle(AppButtonStyle(emphasis: .prominent))
                }
            }
            .controlSize(.small)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppTheme.surface)
            .overlay(alignment: .top) {
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }
        }
        .frame(width: 960, height: 600)
        .sheet(item: $aiRequest) { request in
            ClipAIPromptView(data: request.data, instruction: request.instruction, translation: request.translation)
        }
        .background(AppTheme.canvas)
        .modifier(AppPanel())
        .onAppear {
            localSelection = clips.first
            viewModel.selectedItem = localSelection
            isFocused = true
        }
        .onChange(of: localSelection) { _, newValue in
            viewModel.selectedItem = newValue
        }
    }

    private var sidebar: some View {
        VStack(spacing: 14) {
            SearchBarView(searchText: $searchText, isFocused: $isFocused, onArrowKey: handleArrowKey)
            HStack {
                Text("Clipboard History")
                Spacer()
                Text(filteredClips.count, format: .number)
                    .monospacedDigit()
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)

            if filteredClips.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView("clip.empty.title", systemImage: "clipboard", description: Text("clip.empty.description"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredClips, id: \.objectID) { clipData in
                                Button {
                                    localSelection = clipData
                                } label: {
                                    ClipRowView(
                                        clip: clipData,
                                        isSelected: localSelection?.objectID == clipData.objectID
                                    )
                                }
                                .buttonStyle(AppSelectionStyle(isSelected: localSelection?.objectID == clipData.objectID))
                                .id(clipData.objectID)
                                .contextMenu {
                                    ClipActionsMenu(data: clipData, onTogglePin: { togglePin(clipData) }, onDelete: { delete(clipData) }) { instruction, translation in
                                        requestAI(clipData, instruction: instruction, translation: translation)
                                    }
                                }
                            }
                        }
                        .padding(2)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: localSelection?.objectID.uriRepresentation()) {
                        guard let selected = localSelection else { return }
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.14)) {
                            proxy.scrollTo(selected.objectID, anchor: .center)
                        }
                    }
                }
            }
        }
        .onChange(of: searchText) {
            localSelection = filteredClips.first
        }
        .padding(.vertical, 8)
        .padding(.trailing, 10)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selected = localSelection {
            ClipDataView(data: selected, onTogglePin: { togglePin(selected) }, onDelete: { delete(selected) }) { instruction, translation in
                requestAI(selected, instruction: instruction, translation: translation)
            }
        } else {
            ContentUnavailableView("clip.preview.empty", systemImage: "doc.text.magnifyingglass", description: Text("clip.preview.description"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func handleArrowKey(_ direction: CustomSearchField.ArrowDirection) {
        localSelection = ClipSelection(clips: filteredClips, selected: localSelection).moving(direction)
    }

    private func delete(_ clipData: ClipHistoryData) {
        let newIndexAfterDeletion = ClipSelection(clips: filteredClips, selected: localSelection).indexAfterDeleting(clipData)

        PersistenceController.shared.delete(item: clipData)

        DispatchQueue.main.async {
            let newFiltered = filteredClips
            if let newIndex = newIndexAfterDeletion,
               newFiltered.indices.contains(newIndex) {
                localSelection = newFiltered[newIndex]
            } else if let first = newFiltered.first {
                localSelection = first
            } else {
                localSelection = nil
            }
        }
    }

    private func requestAI(_ clip: ClipHistoryData, instruction: String, translation: Bool) {
        if instruction.isEmpty {
            aiRequest = ClipAIPromptView.Request(data: clip, instruction: instruction, translation: translation)
        } else {
            ActionCoordinator.perform(.ai(instruction: instruction, translation: translation), input: ActionInput(clip: clip),
                                                                                       target: ClipWindowManager.shared.actionTarget ?? ActionTarget())
        }
    }

    private func togglePin(_ clipData: ClipHistoryData) {
        clipData.isPinned.toggle()
        do {
            try viewContext.save()
        } catch {
            print("Failed to toggle pin: \(error)")
        }

        localSelection = clipData
        viewModel.selectedItem = clipData
    }
}

#Preview {
    ClipView()
}
