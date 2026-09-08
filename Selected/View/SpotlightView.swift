import SwiftUI

struct SpotlightView: View {
    let target: ActionTarget
    let bundleID: String
    let allActions: [PerformAction]
    @State private var searchText = ""
    @State private var selectedActionID: String?
    @FocusState private var isFocused: Bool

    private var context: SelectedTextContext {
        ActionInput.textContext(searchText, bundleID: bundleID)
    }

    private var actions: [PerformAction] {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : GetActions(ctx: context, from: allActions)
    }

    var body: some View {
        let availableActions = actions
        let selectedID = selectedActionID ?? availableActions.first?.actionMeta.identifier

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Type or paste text…", text: $searchText)
                    .font(.system(size: 20))
                    .focused($isFocused)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        if let action = availableActions.first(where: { $0.actionMeta.identifier == selectedID }) {
                            perform(action)
                        }
                    }
                    .onKeyPress(.upArrow) { moveSelection(-1, actions: availableActions) }
                    .onKeyPress(.downArrow) { moveSelection(1, actions: availableActions) }
                Button("Close", systemImage: "xmark") {
                    SpotlightWindowManager.shared.forceCloseWindow()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Close")
            }
            .padding(20)

            if !availableActions.isEmpty {
                Divider().padding(.horizontal, 16)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(availableActions, id: \.actionMeta.identifier) { action in
                                Button { perform(action) } label: {
                                    HStack(spacing: 12) {
                                        Icon(action.actionMeta.icon)
                                            .frame(width: 24, height: 24)
                                            .accessibilityHidden(true)
                                        Text(action.actionMeta.title).lineLimit(1)
                                        Spacer(minLength: 8)
                                        if action.actionMeta.identifier == selectedID {
                                            Image(systemName: "return")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(height: 42)
                                    .background(action.actionMeta.identifier == selectedID ? Color.accentColor.opacity(0.12) : .clear,
                                                in: .rect(cornerRadius: 8))
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(action.actionMeta.identifier == selectedID ? .isSelected : [])
                                .id(action.actionMeta.identifier)
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: min(CGFloat(availableActions.count) * 44 + 14, 278))
                    .scrollBounceBehavior(.basedOnSize)
                    .onChange(of: selectedID) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
            }

            HStack(spacing: 8) {
                if let result = calculate(searchText), let value = valueFormatter.string(from: NSNumber(value: result)) {
                    NumerberView(value: value)
                } else {
                    Text(searchText.isEmpty ? "Enter text, then choose an action" : availableActions.isEmpty ? "No matching actions" : "↑ ↓ Choose   ↩ Run")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("esc").font(.caption.monospaced()).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .frame(height: 42)
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
        .onExitCommand { SpotlightWindowManager.shared.forceCloseWindow() }
        .onChange(of: searchText) { selectedActionID = nil }
    }

    private func moveSelection(_ offset: Int, actions: [PerformAction]) -> KeyPress.Result {
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.hasMarkedText() { return .ignored }
        guard !actions.isEmpty else { return .ignored }
        let index = actions.firstIndex { $0.actionMeta.identifier == selectedActionID } ?? 0
        selectedActionID = actions[min(max(index + offset, 0), actions.count - 1)].actionMeta.identifier
        return .handled
    }

    private func perform(_ action: PerformAction) {
        let input = context
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
