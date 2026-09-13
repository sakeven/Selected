import SwiftUI

struct SpotlightResultsView: View {
    let results: [SpotlightItem]
    let selectedID: String?
    let isSearchMode: Bool
    let select: (SpotlightItem) -> Void
    let preview: (URL) -> Void
    let reveal: (URL) -> Void

    var body: some View {
        let listItems = results.filter { $0.group != nil }
        let grouped = Dictionary(grouping: listItems, by: \.group)
        let groups = SpotlightItem.Group.allCases.filter { grouped[$0] != nil }

        VStack(spacing: 0) {
            if !listItems.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(groups, id: \.self) { group in
                                Section {
                                    ForEach(grouped[group] ?? []) { item in
                                        SpotlightResultRow(item: item, isSelected: item.id == selectedID,
                                                           run: { select(item) }, preview: preview, reveal: reveal)
                                            .id(item.id)
                                    }
                                } header: {
                                    if isSearchMode {
                                        Text(group.title)
                                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                            .padding(.horizontal, 12)
                                            .frame(height: 28, alignment: .leading)
                                            .accessibilityAddTraits(.isHeader)
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }
                    .frame(height: min(CGFloat(listItems.count) * 56 + CGFloat(isSearchMode ? groups.count : 0) * 30 + 14, 350))
                    .scrollBounceBehavior(.basedOnSize)
                    .onChange(of: selectedID) { _, id in
                        if let id, listItems.contains(where: { $0.id == id }) { proxy.scrollTo(id) }
                    }
                }
            }
            if let textEntry = results.first(where: { $0.id == "text-actions" }) {
                if !listItems.isEmpty { Divider().padding(.horizontal, 16) }
                SpotlightResultRow(item: textEntry, isSelected: textEntry.id == selectedID,
                                   run: { select(textEntry) }, preview: preview, reveal: reveal)
                    .padding(8)
            }
        }
    }
}
