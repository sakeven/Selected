import Foundation

struct TTSCache {
    private struct Entry {
        let data: Data
        let storedAt: Date
    }

    private var entries: [Int: Entry] = [:]

    mutating func data(for text: String, at date: Date) -> Data? {
        entries = entries.filter { $0.value.storedAt.addingTimeInterval(120) >= date }
        return entries[text.hash]?.data
    }

    mutating func store(_ data: Data, for text: String, at date: Date) {
        entries[text.hash] = Entry(data: data, storedAt: date)
    }
}
