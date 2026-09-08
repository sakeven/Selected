import Foundation

struct ClipSelection {
    let clips: [ClipHistoryData]
    let selected: ClipHistoryData?

    func moving(_ direction: CustomSearchField.ArrowDirection) -> ClipHistoryData? {
        guard !clips.isEmpty else { return selected }
        let index = selected.flatMap { clips.firstIndex(of: $0) }
        if direction == .down {
            if let index, index < clips.count - 1 { return clips[index + 1] }
            return clips.first
        }
        if let index, index > 0 { return clips[index - 1] }
        return selected
    }

    func indexAfterDeleting(_ clip: ClipHistoryData) -> Int? {
        let selectedIndex = selected.flatMap { clips.firstIndex(of: $0) } ?? 0
        let deletedIndex = clips.firstIndex(of: clip) ?? 0

        if selected == clip {
            if clips.count > deletedIndex + 1 { return deletedIndex }
            return deletedIndex > 0 ? deletedIndex - 1 : nil
        }
        if deletedIndex < selectedIndex {
            return selectedIndex > 0 ? selectedIndex - 1 : 0
        }
        return selectedIndex
    }
}
