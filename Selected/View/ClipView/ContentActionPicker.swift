import SwiftUI

struct ContentActionPicker: View {
    let input: ActionInput
    let onSelect: (ActionRequest) -> Void
    @ObservedObject private var manager = PluginManager.shared
    @State private var search = ""
    @FocusState private var focused: Bool

    private var entries: [ActionCatalog.Entry] {
        ActionCatalog.entries(input: input, manager: manager).filter {
            search.isEmpty || $0.title.localizedStandardContains(search) || $0.group.localizedStandardContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search actions or plugins", text: $search)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit {
                    if let entry = entries.first { onSelect(entry.request) }
                }
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(entries) { entry in
                        Button { onSelect(entry.request) } label: {
                            HStack(spacing: 10) {
                                Icon(entry.icon).frame(width: 24, height: 24).foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.title).foregroundStyle(.primary)
                                    if entry.group != entry.title {
                                        Text(entry.group).font(.caption).foregroundStyle(.secondary)
                                    }
                                    if entry.includesClipboard {
                                        Label("Includes clipboard text", systemImage: "clipboard").font(.caption).foregroundStyle(.blue)
                                    }
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                    if entries.isEmpty { Text("No matching actions").foregroundStyle(.secondary).padding() }
                }
            }
        }
        .padding(14)
        .frame(width: 330, height: 340)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { focused = true }
    }
}
