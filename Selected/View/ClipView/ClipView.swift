//
//  ClipView.swift
//  Selected
//
//  Created by sake on 2024/4/7.
//

import AppKit
import CoreData
import SwiftUI

struct ClipView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: false)],
        animation: .default
    )
    private var clips: FetchedResults<ClipHistoryData>

    @ObservedObject var viewModel: ClipViewModel
    var restore: (ClipHistoryData, Bool) -> Void = ClipWindowManager.shared.restore(_:paste:)
    @State private var isFocused = true

    @State private var searchText = ""
    @State private var aiRequest: ClipAIPromptView.Request?
    @State private var pluginClip: ClipHistoryData?

    private var filteredClips: [ClipHistoryData] {
        var pinned: [ClipHistoryData] = []
        var recent: [ClipHistoryData] = []
        // Older records can store nil for an unpinned item. Keep them in the same date order as false.
        for clip in clips where clip.matchesSearch(searchText) {
            if clip.isPinned {
                pinned.append(clip)
            } else {
                recent.append(clip)
            }
        }
        return pinned + recent
    }

    var body: some View {
        let results = filteredClips
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                SearchBarView(searchText: $searchText, isFocused: $isFocused, onArrowKey: handleArrowKey)
                    .help(Text("clip.search") + Text(verbatim: "  ⌘F"))
                Button {
                    ClipWindowManager.shared.forceCloseWindow()
                } label: {
                    ShortcutHint(keys: "esc")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("clip.dismiss")
                .help("clip.dismiss.shortcut")
            }
            .padding(.horizontal, 22)
            .frame(height: 54)
            Divider()

            if results.isEmpty {
                Group {
                    if searchText.isEmpty {
                        ContentUnavailableView("clip.empty.title", systemImage: "clipboard", description: Text("clip.empty.description"))
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    sidebar(results)
                        .frame(width: 316)
                        .background(AppTheme.canvas)
                    Divider()
                    detailPane
                }
                Divider()
                actionBar
            }
        }
        .frame(width: 960, height: 600)
        .sheet(item: $aiRequest) { request in
            ClipAIPromptView(data: request.data, instruction: request.instruction, translation: request.translation)
        }
        .modifier(AppPanel(cornerRadius: 16))
        .onAppear {
            isFocused = true
        }
        .onDisappear { viewModel.performShortcut = nil }
        .onChange(of: searchText) {
            viewModel.selectedItem = filteredClips.first
        }
        .onChange(of: results, initial: true) {
            viewModel.performShortcut = { handleShortcut($0, results: results) }
            if viewModel.selectedItem == nil { viewModel.selectedItem = results.first }
        }
    }

    private func sidebar(_ results: [ClipHistoryData]) -> some View {
        let pinned = results.prefix(while: \.isPinned)
        let shortcutIDs = viewModel.showsQuickPasteKeys ? results.prefix(9).map(\.objectID) : []
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    historySection("clip.pinned", items: pinned, shortcutIDs: shortcutIDs)
                    historySection("Recently Copied", items: results.dropFirst(pinned.count), shortcutIDs: shortcutIDs)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .onChange(of: viewModel.selectedItem?.objectID) {
                guard let selected = viewModel.selectedItem else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.14)) {
                    proxy.scrollTo(selected.objectID)
                }
            }
        }
    }

    @ViewBuilder
    private func historySection(_ title: LocalizedStringKey, items: ArraySlice<ClipHistoryData>, shortcutIDs: [NSManagedObjectID]) -> some View {
        if !items.isEmpty {
            HStack {
                Text(title)
                Spacer()
                Text(items.count, format: .number).monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ForEach(items, id: \.objectID) { clip in
                Button {
                    viewModel.selectedItem = clip
                } label: {
                    ClipRowView(clip: clip, isSelected: viewModel.selectedItem == clip,
                                shortcutNumber: shortcutIDs.firstIndex(of: clip.objectID).map { $0 + 1 })
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.selectedItem == clip ? .isSelected : [])
                .contextMenu {
                    Button("clip.pasteOriginal", systemImage: "return") {
                        restore(clip, true)
                    }
                    Button("clip.copy", systemImage: "doc.on.doc") {
                        restore(clip, false)
                    }
                    Divider()
                    itemActions(clip)
                }
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selected = viewModel.selectedItem {
            ClipDataView(data: selected) { togglePin(selected) }
                .id(selected.objectID)
        } else {
            ContentUnavailableView("clip.preview.empty", systemImage: "doc.text.magnifyingglass", description: Text("clip.preview.description"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            ShortcutHint(keys: "↑")
            ShortcutHint(keys: "↓", title: "clip.navigate")
            if viewModel.showsQuickPasteKeys {
                ShortcutHint(keys: "⌘1–9", title: "Quick Paste")
                    .padding(.leading, 8)
            } else {
                ShortcutHint(keys: "⌘", title: "Hold for shortcuts")
                    .padding(.leading, 8)
            }
            Spacer()
            if let selected = viewModel.selectedItem {
                Menu("More actions") {
                    itemActions(selected)
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .buttonStyle(AppButtonStyle(emphasis: .quiet))
                .popover(item: $pluginClip) { clip in
                    ContentActionPicker(input: ActionInput(clip: clip)) { request in
                        pluginClip = nil
                        ActionCoordinator.perform(request, input: ActionInput(clip: clip), target: ClipWindowManager.shared.actionTarget ?? ActionTarget())
                    }
                }
                Button {
                    restore(selected, false)
                } label: {
                    HStack(spacing: 6) {
                        Text("clip.copy.short")
                        if viewModel.showsQuickPasteKeys { Text(verbatim: "⌘↩").foregroundStyle(.secondary) }
                    }
                }
                .buttonStyle(AppButtonStyle(emphasis: .quiet))
                .help(Text("clip.copy") + Text(verbatim: "  ⌘↩"))
                Button {
                    restore(selected, true)
                } label: {
                    HStack(spacing: 12) {
                        Text("clip.paste")
                        Image(systemName: "return").accessibilityHidden(true)
                    }
                }
                .buttonStyle(AppButtonStyle(emphasis: .prominent))
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 58)
    }

    private func itemActions(_ clip: ClipHistoryData) -> some View {
        ClipActionsMenu(data: clip, onTogglePin: { togglePin(clip) }, onDelete: { delete(clip) }, onShowPlugins: { pluginClip = clip }) { instruction, translation in
            requestAI(clip, instruction: instruction, translation: translation)
        }
    }

    private func handleArrowKey(_ direction: CustomSearchField.ArrowDirection) {
        viewModel.selectedItem = ClipSelection(clips: filteredClips, selected: viewModel.selectedItem).moving(direction)
    }

    private func handleShortcut(_ shortcut: ClipShortcut, results: [ClipHistoryData]) -> Bool {
        guard aiRequest == nil, pluginClip == nil else { return false }
        switch shortcut {
        case .focusSearch:
            isFocused = true
        case .quickPaste(let number):
            guard results.indices.contains(number - 1) else { return false }
            restore(results[number - 1], true)
        case .copy, .paste:
            guard let selected = viewModel.selectedItem else { return false }
            restore(selected, shortcut == .paste)
        case .pastePlainText:
            guard let text = viewModel.selectedItem?.plainText else { return false }
            ClipWindowManager.shared.pastePlainText(text)
        case .togglePin:
            guard let selected = viewModel.selectedItem else { return false }
            togglePin(selected)
        case .delete:
            guard let selected = viewModel.selectedItem else { return false }
            delete(selected)
        }
        return true
    }

    private func delete(_ clipData: ClipHistoryData) {
        let selection = ClipSelection(clips: filteredClips, selected: viewModel.selectedItem)
        let index = selection.indexAfterDeleting(clipData)
        let remaining = selection.clips.filter { $0 != clipData }
        PersistenceController.shared.delete(item: clipData)
        if let index, remaining.indices.contains(index) {
            viewModel.selectedItem = remaining[index]
        } else {
            viewModel.selectedItem = remaining.first
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

        viewModel.selectedItem = clipData
    }
}

#Preview {
    ClipView(viewModel: ClipViewModel())
}
