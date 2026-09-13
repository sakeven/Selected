import SwiftUI

struct SpotlightView: View {
    let target: ActionTarget
    @State private var search: SpotlightSearch
    @State private var previewURL: URL?
    @State private var openError: String?
    @State private var isFocused = true

    init(target: ActionTarget, bundleID: String, allActions: [PerformAction]) {
        self.target = target
        _search = State(initialValue: SpotlightSearch(allActions: allActions, bundleID: bundleID))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !search.isSearchMode || search.searchGroup != nil {
                HStack(spacing: 8) {
                    Button("Back to Search", systemImage: "chevron.left") { search.backToSearch(); isFocused = true }
                        .labelStyle(.iconOnly).buttonStyle(.plain).help("Back to Search")
                    if case .action(let action) = search.mode {
                        Text(action.actionMeta.title).lineLimit(1)
                    } else if search.isSearchMode, let group = search.searchGroup {
                        Text(group.title)
                    } else {
                        Text("Actions for Input Text")
                    }
                    Spacer()
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 20).padding(.top, 14)
            }

            HStack(spacing: 12) {
                Image(systemName: search.isSearchMode ? "magnifyingglass" : "text.cursor")
                    .font(.title2.weight(.medium)).foregroundStyle(.secondary).accessibilityHidden(true)
                SpotlightSearchField(text: $search.text, isFocused: $isFocused,
                                     placeholder: search.isSearchMode ? String(localized: "Search apps, files, and more…") : String(localized: "Type or paste text…"),
                                     moveSelection: search.moveSelection,
                                     submit: { if let item = search.selectedResult { select(item) } },
                                     tab: {
                                         guard search.isSearchMode, !search.text.isEmpty else { return false }
                                         search.chooseTextActions()
                                         return true
                                     }, cancel: dismissOrBack)
                Button("Close", systemImage: "xmark") { SpotlightWindowManager.shared.forceCloseWindow() }
                    .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.tertiary).help("Close")
            }
            .padding(20)

            if !search.results.isEmpty {
                Divider().padding(.horizontal, 16)
                SpotlightResultsView(results: search.results, selectedID: search.selectedResult?.id,
                                     isSearchMode: search.isSearchMode && search.searchGroup == nil, select: select,
                                     preview: { previewURL = $0 }, reveal: reveal)
            } else if !search.isSearchMode {
                Text(search.text.isEmpty ? "Enter text to use this action" : "No actions available for this text in the current app")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.horizontal, 20).padding(.bottom, 16)
            } else if search.searchGroup != nil {
                Text(search.text.isEmpty ? "Search in this category" : "No results in this category")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.horizontal, 20).padding(.bottom, 16)
            }

            HStack(spacing: 8) {
                if let result = calculate(search.text), let value = valueFormatter.string(from: NSNumber(value: result)) {
                    NumerberView(value: value)
                } else if search.isSearchingFiles && (search.searchGroup == nil || search.searchGroup == .files) {
                    ProgressView().controlSize(.mini)
                    Text("Searching files…")
                } else if search.fileSearchFailed && (search.searchGroup == nil || search.searchGroup == .files) {
                    Text("File search is unavailable")
                } else if search.clipboardSearchFailed && (search.searchGroup == nil || search.searchGroup == .clipboard) {
                    Text("Clipboard search is unavailable")
                } else if search.text.isEmpty {
                    Text(search.isSearchMode ? "Apps, actions, files, and clipboard" : "Enter text, then choose an action")
                } else if case .clipboard = search.selectedResult?.content {
                    Text("↑ ↓ Choose   ↩ Paste")
                } else {
                    Text("↑ ↓ Choose   ↩ Run")
                }
                Spacer(minLength: 4)
                if case .file(let url) = search.selectedResult?.content {
                    Button("Quick Look", systemImage: "eye") { previewURL = url }
                        .labelStyle(.iconOnly).buttonStyle(.plain).help("Quick Look (⌘Y)")
                        .keyboardShortcut("y", modifiers: .command)
                    Button("Show in Finder", systemImage: "folder") { reveal(url) }
                        .labelStyle(.iconOnly).buttonStyle(.plain).help("Show in Finder (⌘↩)")
                        .keyboardShortcut(.return, modifiers: .command)
                    Button("Copy Path", systemImage: "doc.on.doc") { copyText(url.path) }
                        .labelStyle(.iconOnly).buttonStyle(.plain).help("Copy Path (⌘⇧C)")
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                } else if case .clipboard(let clip) = search.selectedResult?.content {
                    Button("clip.copy.short", systemImage: "doc.on.doc") {
                        ClipService.shared.restore(clip) { SpotlightWindowManager.shared.forceCloseWindow() }
                    }
                    .buttonStyle(.plain).help("clip.copy")
                    .keyboardShortcut(.return, modifiers: .command)
                }
                Text("esc").font(.caption.monospaced()).foregroundStyle(.tertiary)
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 20).frame(height: 42)
            .background(.primary.opacity(0.025))
        }
        .frame(width: 520)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10), lineWidth: 0.5)
        }
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { isFocused = true }
        .task { await search.loadApplications() }
        .onDisappear { search.stop() }
        .onExitCommand(perform: dismissOrBack)
        .sheet(isPresented: Binding(get: { previewURL != nil }, set: { if !$0 { previewURL = nil } })) {
            if let previewURL {
                VStack(spacing: 12) {
                    HStack {
                        Text(previewURL.lastPathComponent).font(.headline).lineLimit(1)
                        Spacer()
                        Button("Done") { self.previewURL = nil }.keyboardShortcut(.cancelAction)
                    }
                    QuickLookPreview(url: previewURL).frame(width: 560, height: 360)
                }
                .padding(16)
            }
        }
        .alert("Could Not Complete Action", isPresented: Binding(get: { openError != nil }, set: { if !$0 { openError = nil } })) {
            Button("OK") { openError = nil }
        } message: { Text(openError ?? "") }
    }

    private func dismissOrBack() {
        if previewURL != nil { previewURL = nil }
        else if search.isSearchMode && search.searchGroup == nil { SpotlightWindowManager.shared.forceCloseWindow() }
        else { search.backToSearch(); isFocused = true }
    }

    private func select(_ item: SpotlightItem) {
        switch item.content {
        case .application(let url), .file(let url):
            if NSWorkspace.shared.open(url) { SpotlightWindowManager.shared.forceCloseWindow() }
            else { openError = String(localized: "The item may have moved or is no longer accessible.") }
        case .action(let action):
            if search.isSearchMode { search.chooseAction(action); isFocused = true }
            else { perform(action) }
        case .textActions:
            search.chooseTextActions()
            isFocused = true
        case .more(let group):
            search.chooseGroup(group)
            isFocused = true
        case .clipboard(let clip):
            Task {
                do {
                    try await target.activate()
                    ClipService.shared.restore(clip) {
                        PressPasteKey()
                        SpotlightWindowManager.shared.forceCloseWindow()
                    }
                } catch {
                    openError = error.localizedDescription
                }
            }
        }
    }

    private func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
        SpotlightWindowManager.shared.forceCloseWindow()
    }

    private func perform(_ action: PerformAction) {
        let input = search.context
        let position = SpotlightWindowManager.shared.resultPosition
        SpotlightWindowManager.shared.forceCloseWindow()
        if let pluginID = action.pluginInfo?.id,
           let plugin = PluginManager.shared.plugins.first(where: { $0.id == pluginID }),
           let definition = plugin.actions.first(where: { $0.meta.identifier == action.actionMeta.identifier }) {
            ActionCoordinator.perform(.plugin(plugin, definition), input: ActionInput(context: input), target: target, resultPosition: position)
        } else if let complete = action.complete {
            complete(input)
        } else if let complete = action.completeAsync {
            Task { await complete(input) }
        }
    }
}

#Preview {
    SpotlightView(target: ActionTarget(application: nil), bundleID: "", allActions: [])
}
