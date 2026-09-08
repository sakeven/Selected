import AppKit
import CoreData
import Testing
@testable import Selected

@MainActor
struct ClipboardPersistenceTests {
    @Test func storingPreservesMetadataAndOrderedRepresentationBytes() throws {
        let controller = try controller()
        var snapshot = try snapshot(text: "Hello 世界")
        snapshot.appBundleID = "test.app"
        snapshot.timeStamp = 1_000_123
        snapshot.url = "https://example.com"
        snapshot.items.append(ClipItem(type: .html, data: Data("<b>Hello 世界</b>".utf8)))
        controller.store(snapshot, in: controller.container.viewContext)
        let stored = try #require(clips(controller).first)
        #expect(stored.application == "test.app")
        #expect(stored.plainText == "Hello 世界")
        #expect(stored.url == "https://example.com")
        #expect(stored.numberOfCopies == 1)
        #expect(!stored.isPinned)
        #expect(stored.firstCopiedAt == Date(timeIntervalSince1970: 1000.123))
        #expect(stored.lastCopiedAt == stored.firstCopiedAt)
        #expect(stored.getItems().map(\.type) == snapshot.items.map { $0.type.rawValue })
        #expect(stored.getItems().map(\.data) == snapshot.items.map(\.data))
        #expect(stored.getItems().allSatisfy { $0.refer == stored })
        #expect(stored.md5 == MD5(string: "Hello 世界<b>Hello 世界</b>"))
    }

    @Test func duplicateCopyKeepsFirstDatePinAndIncrementsCount() throws {
        let controller = try controller()
        var first = try snapshot(text: "Same text")
        first.timeStamp = 1_000_000
        controller.store(first, in: controller.container.viewContext)
        let original = try #require(clips(controller).first)
        original.isPinned = true
        controller.updateClipHistoryData(original, updateCount: false)
        var second = first
        second.timeStamp = 2_000_000
        second.appBundleID = "new.app"
        controller.store(second, in: controller.container.viewContext)
        let stored = try clips(controller)
        #expect(stored.count == 1)
        #expect(stored.first?.firstCopiedAt == Date(timeIntervalSince1970: 1000))
        #expect(stored.first?.lastCopiedAt == Date(timeIntervalSince1970: 2000))
        #expect(stored.first?.numberOfCopies == 2)
        #expect(stored.first?.isPinned == true)
        #expect(stored.first?.application == "new.app")
        #expect(try controller.container.viewContext.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "ClipHistoryItem")) == 1)
    }

    @Test func retentionKeepsPinnedAndBoundaryRecords() throws {
        let controller = try controller()
        for (text, timestamp, pinned) in [("expired", 1000, false), ("pinned", 1000, true), ("boundary", 2000, false), ("recent", 3000, false)] {
            var data = try snapshot(text: text)
            data.timeStamp = Int64(timestamp * 1000)
            controller.store(data, in: controller.container.viewContext)
            let clip = try #require(clips(controller).first { $0.plainText == text })
            clip.isPinned = pinned
            controller.updateClipHistoryData(clip, updateCount: false)
        }
        controller.deleteBefore(byDate: Date(timeIntervalSince1970: 2000))
        #expect(Set(try clips(controller).compactMap(\.plainText)) == ["pinned", "boundary", "recent"])
        let pinned = try #require(clips(controller).first { $0.isPinned })
        controller.delete(item: pinned)
        #expect(Set(try clips(controller).compactMap(\.plainText)) == ["boundary", "recent"])
        #expect(try controller.container.viewContext.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "ClipHistoryItem")) == 2)
    }

    @Test func copyUpdatesCanBeDisabledWithoutChangingTimestamp() throws {
        let controller = try controller()
        controller.store(try snapshot(text: "Text"), in: controller.container.viewContext)
        let clip = try #require(clips(controller).first)
        let date = clip.lastCopiedAt
        clip.isPinned = true
        controller.updateClipHistoryData(clip, updateCount: false)
        #expect(clip.numberOfCopies == 1)
        #expect(clip.lastCopiedAt == date)
        let before = Date()
        controller.updateClipHistoryData(clip)
        #expect(clip.numberOfCopies == 2)
        #expect(try #require(clip.lastCopiedAt) >= before)
        #expect(clip.isPinned)
    }

    @Test func calendarRetentionPreservesMonthAndLeapYearSemantics() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2024, month: 8, day: 31, hour: 12))!
        let expected: [(ClipboardHistoryTime, DateComponents)] = [
            (.OneDay, .init(year: 2024, month: 8, day: 30, hour: 12)),
            (.SevenDays, .init(year: 2024, month: 8, day: 24, hour: 12)),
            (.ThirtyDays, .init(year: 2024, month: 8, day: 1, hour: 12)),
            (.ThreeMonths, .init(year: 2024, month: 5, day: 31, hour: 12)),
            (.SixMonths, .init(year: 2024, month: 2, day: 29, hour: 12)),
            (.OneYear, .init(year: 2023, month: 8, day: 31, hour: 12))
        ]
        for (retention, components) in expected {
            #expect(retention.cutoffDate(relativeTo: date, calendar: calendar) == calendar.date(from: components))
        }
    }

    private func controller() throws -> PersistenceController {
        let model = PersistenceController.shared.container.managedObjectModel
        let container = NSPersistentContainer(name: "ClipHistory", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        return PersistenceController(container: container)
    }

    private func snapshot(text: String) throws -> ClipData {
        let pasteboard = NSPasteboard(name: .init("persistence-test-\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString(text, forType: .string)
        return try #require(ClipData(pasteboard: pasteboard))
    }

    private func clips(_ controller: PersistenceController) throws -> [ClipHistoryData] {
        try controller.container.viewContext.fetch(NSFetchRequest<ClipHistoryData>(entityName: "ClipHistoryData"))
    }
}
