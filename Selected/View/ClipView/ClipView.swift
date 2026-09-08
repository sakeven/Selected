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
    @Environment(\.colorScheme) private var colorScheme
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
    @FocusState private var isFocused: Bool

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
            HStack(spacing: 16) {
                Label("Clipboard", systemImage: "clipboard")
                    .font(.headline)
                    .foregroundStyle(.primary)

                SearchBarView(searchText: $searchText, onArrowKey: handleArrowKey)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(colorScheme.clipDivider).frame(height: 1)
            }

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 320)

                Rectangle()
                    .fill(colorScheme.clipDivider)
                    .frame(width: 1)

                detailPane
                    .frame(minWidth: 500)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            HStack(spacing: 16) {
                Label("clip.navigate", systemImage: "arrow.up.arrow.down")
                Button {
                    ClipWindowManager.shared.forceCloseWindow()
                } label: {
                    HStack(spacing: 6) {
                        Text(verbatim: "Esc")
                            .monospaced()
                        Text("clip.dismiss")
                    }
                }
                .buttonStyle(.plain)
                .help("clip.dismiss.shortcut")
                Spacer()

                if let selected = localSelection {
                    Button("clip.copy.short", systemImage: "doc.on.doc") {
                        ClipWindowManager.shared.restore(selected, paste: false)
                    }
                    .buttonStyle(SettingsButtonStyle())
                    .help("clip.copy")

                    HStack(spacing: 4) {
                        Button("clip.paste", systemImage: "return") {
                            ClipWindowManager.shared.restore(selected, paste: true)
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
                    .buttonStyle(SettingsButtonStyle(emphasis: .prominent))
                }
            }
            .controlSize(.small)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(colorScheme.clipPanelFill)
            .overlay(alignment: .top) {
                Rectangle().fill(colorScheme.clipDivider).frame(height: 1)
            }
        }
        .frame(width: 960, height: 600)
        .sheet(item: $aiRequest) { request in
            ClipAIPromptView(data: request.data, instruction: request.instruction, translation: request.translation)
        }
        .background {
            LinearGradient(
                colors: colorScheme.clipBackdropColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(colorScheme.clipShellStroke, lineWidth: 1)
        }
        .onAppear {
            localSelection = clips.first
            viewModel.selectedItem = localSelection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onChange(of: localSelection) { _, newValue in
            viewModel.selectedItem = newValue
        }
        .focused($isFocused)
    }

    private var sidebar: some View {
        VStack(spacing: 10) {
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
                                .buttonStyle(.plain)
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
