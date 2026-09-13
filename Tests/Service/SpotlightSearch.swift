import AppKit
import CoreData
import XCTest
@testable import Selected

@MainActor
final class SpotlightSearchTests: XCTestCase {
    private let configuration = UserConfiguration(defaultActions: [], appConditions: [], urlConditions: [])

    func testRankingPrefersExactAndPrefixMatchesAndSupportsAbbreviations() {
        let items = [item("My Notes"), item("Notes 2"), item("Notes"), item("Notes 10"), item("Notepad")]
        XCTAssertEqual(SpotlightSearch.ranked(items, matching: "notes", limit: 4).map(\.title),
                       ["Notes", "Notes 2", "Notes 10", "My Notes"])
        XCTAssertEqual(item("Visual Studio Code").matchScore("vsc"), 2)
        XCTAssertEqual(item("Café").matchScore("CAFE"), 0)
        XCTAssertNil(item("Notes").matchScore("Safari"))
        var localized = item("预览")
        localized.searchNames = ["Preview"]
        XCTAssertNotNil(localized.matchScore("pre"))
        XCTAssertNotNil(localized.matchScore("预览"))
    }

    func testChoosingAnActionDoesNotExecuteTheSearchTerm() {
        var executed: [String] = []
        let action = PerformAction(actionMeta: GenericAction(title: "Translate", icon: "symbol:globe", identifier: "translate"),
                                   complete: { executed.append($0.Text) })
        action.actionMeta.requirements = [.text]
        let search = makeSearch([action])
        defer { search.stop() }
        search.text = "trans"
        XCTAssertEqual(search.results.first?.id, "action:translate")
        search.chooseAction(action)
        XCTAssertTrue(executed.isEmpty)
        XCTAssertEqual(search.text, "")
        XCTAssertTrue(search.results.isEmpty)
        search.text = "The actual input"
        XCTAssertEqual(search.results.first?.id, "action:translate")
        XCTAssertEqual(search.context.Text, "The actual input")
        XCTAssertEqual(search.context.BundleID, "test.app")
        search.backToSearch()
        XCTAssertEqual(search.text, "trans")
        XCTAssertTrue(search.isSearchMode)
    }

    func testTextActionsPreserveOriginalWhitespaceAndDetectLinks() {
        let action = makeAction("Open Link")
        action.actionMeta.requirements = [.url]
        let search = makeSearch([action])
        defer { search.stop() }
        let original = "  See https://example.com/path\n请阅读这段内容。  "
        search.text = original
        XCTAssertEqual(search.results.first?.id, "text-actions")
        XCTAssertFalse(search.isSearchingFiles)
        search.chooseTextActions()
        XCTAssertEqual(search.context.Text, original)
        XCTAssertEqual(search.context.URLs, ["https://example.com/path"])
        XCTAssertTrue(search.results.contains { $0.id == "action:Open Link" })
        search.backToSearch()
        XCTAssertEqual(search.text, original)
    }

    func testSelectedActionStillChecksItsRequirementsAndSupportedPredicate() {
        let action = makeAction("Link Action")
        action.actionMeta.requirements = [.url]
        action.supported = { !$0.Text.contains("blocked") }
        let search = makeSearch([action])
        defer { search.stop() }
        search.chooseAction(action)
        search.text = "plain text"
        XCTAssertTrue(search.results.isEmpty)
        search.text = "https://example.com"
        XCTAssertEqual(search.results.count, 1)
        search.text = "https://example.com/blocked"
        XCTAssertTrue(search.results.isEmpty)
    }

    func testAppRestrictionsApplyToActionDiscovery() {
        let hidden = makeAction("Hidden Action")
        hidden.actionMeta.excludedApps = ["test.app"]
        let otherApp = makeAction("Other Action")
        otherApp.actionMeta.requiredApps = ["other.app"]
        let visible = makeAction("Visible Action")
        let search = makeSearch([hidden, otherApp, visible])
        defer { search.stop() }
        search.text = "Action"
        XCTAssertEqual(search.results.map(\.id), ["action:Visible Action", "text-actions"])
    }

    func testTextActionsPreserveConfiguredOrderAndHaveUniqueRows() {
        let configured = UserConfiguration(defaultActions: ["B", "A", "B"], appConditions: [], urlConditions: [])
        let search = SpotlightSearch(allActions: [makeAction("A"), makeAction("B"), makeAction("C")],
                                     bundleID: "test.app", configuration: configured)
        defer { search.stop() }
        search.text = "example text"
        search.chooseTextActions()
        XCTAssertEqual(search.results.map(\.id), ["action:B", "action:A"])
    }

    func testExplicitActionSearchIsNotLimitedToPopBarShortlist() {
        let action = makeAction("Extra Action")
        action.actionMeta.requirements = [.text]
        let configured = UserConfiguration(defaultActions: ["Copy"], appConditions: [], urlConditions: [])
        let search = SpotlightSearch(allActions: [makeAction("Copy"), action], bundleID: "test.app", configuration: configured)
        defer { search.stop() }
        search.text = "Extra Action"
        search.chooseAction(action)
        search.text = "Actual input"
        XCTAssertEqual(search.results.map(\.id), ["action:Extra Action"])
        action.actionMeta.excludedApps = ["test.app"]
        search.text = "Different input"
        XCTAssertTrue(search.results.isEmpty)
    }

    func testSelectionClampsAndResetsWhenInputChanges() {
        let search = makeSearch([makeAction("Action A"), makeAction("Action B")])
        defer { search.stop() }
        search.text = "Action"
        search.moveSelection(1)
        XCTAssertEqual(search.selectedResult?.id, "action:Action B")
        search.moveSelection(100)
        XCTAssertEqual(search.selectedResult?.id, "text-actions")
        search.moveSelection(-100)
        XCTAssertEqual(search.selectedResult?.id, "action:Action A")
        search.text = "Action B"
        XCTAssertEqual(search.selectedResult?.id, "action:Action B")
        search.text = ""
        XCTAssertNil(search.selectedResult)
        XCTAssertFalse(search.isSearchingFiles)
    }

    func testLongInputPrioritizesTextActionsWithoutAFileQuery() {
        let search = makeSearch([])
        defer { search.stop() }
        search.text = String(repeating: "内容", count: 45)
        XCTAssertEqual(search.results.first?.id, "text-actions")
        XCTAssertFalse(search.isSearchingFiles)
    }

    func testLongInputKeepsTextEntryAtBottomAndSelectsItByDefault() {
        let text = String(repeating: "Long action name ", count: 6)
        let search = makeSearch([makeAction(text)])
        defer { search.stop() }
        search.text = text
        XCTAssertEqual(search.results.map(\.id), ["action:" + text, "text-actions"])
        XCTAssertEqual(search.selectedResult?.id, "text-actions")
        search.moveSelection(-1)
        XCTAssertEqual(search.selectedResult?.id, "action:" + text)
        search.moveSelection(1)
        XCTAssertEqual(search.selectedResult?.id, "text-actions")
    }

    func testFileQueryTreatsUserInputLiterallyAndExcludesApps() {
        let predicate = SpotlightSearch.filePredicate("report's [draft]*")
        let file: [String: Any] = ["kMDItemFSName": "Report's [draft]*.pdf", "kMDItemContentType": "com.adobe.pdf"]
        XCTAssertTrue(predicate.evaluate(with: file))
        var app = file
        app["kMDItemContentType"] = "com.apple.application-bundle"
        XCTAssertFalse(predicate.evaluate(with: app))
        XCTAssertFalse(SpotlightSearch.filePredicate("*").evaluate(with: ["kMDItemFSName": "Notes.pdf"]))
    }

    func testApplicationDiscoveryFindsUtilitiesAndSkipsPackageContents() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("spotlight-apps-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["Editor.app/Contents", "Utilities/Terminal.app/Contents", "Editor.app/Contents/Helper.app", ".Hidden.app"] {
            try FileManager.default.createDirectory(at: directory.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        let applications = SpotlightSearch.installedApplications(in: [directory])
        XCTAssertEqual(Set(applications.map(\.title)), ["Editor", "Terminal"])
        XCTAssertTrue(applications.allSatisfy { $0.url?.pathExtension == "app" })
    }

    func testInstalledApplicationSearchFindsTextEditByItsBundleName() async {
        let search = makeSearch([])
        defer { search.stop() }
        search.text = "TextEdit"
        await search.loadApplications()
        XCTAssertTrue(search.results.contains { $0.url?.lastPathComponent == "TextEdit.app" })
    }

    func testMatchingApplicationsPrecedeAnExactActionMatch() async throws {
        let search = makeSearch([makeAction("Text")])
        defer { search.stop() }
        search.text = "Text"
        await search.loadApplications()
        let actionIndex = try XCTUnwrap(search.results.firstIndex { $0.id == "action:Text" })
        let applicationIndices = search.results.indices.filter {
            if case .application = search.results[$0].content { return true }
            return false
        }
        XCTAssertFalse(applicationIndices.isEmpty)
        XCTAssertTrue(applicationIndices.allSatisfy { $0 < actionIndex })
    }

    func testSearchOverviewLimitsEveryGroupIncludingFilesAndFolders() throws {
        let files = (1...12).map {
            SpotlightItem.file(URL(fileURLWithPath: "/Users/example/Documents/Report \($0)", isDirectory: $0.isMultiple(of: 2)))
        }
        let apps = (1...5).map { item("Report App \($0)") }
        let actions = (1...5).map { SpotlightItem.action(makeAction("Report Action \($0)")) }
        let clipboard = try (1...5).map { index in
            SpotlightItem.clipboard(try makeClipboardFixture(text: "Report clip \(index)"))
        }
        let results = SpotlightSearch.previewResults(files + clipboard + apps + actions)
        var expected = apps.prefix(3).map(\.id) + ["more:applications"]
        expected += actions.prefix(3).map(\.id) + ["more:actions"]
        expected += files.prefix(3).map(\.id) + ["more:files"]
        expected += clipboard.prefix(3).map(\.id) + ["more:clipboard"]
        XCTAssertEqual(results.map(\.id), expected)
        XCTAssertEqual(SpotlightSearch.previewResults(Array(files.prefix(3))).map(\.id), Array(files.prefix(3)).map(\.id))
        XCTAssertTrue(SpotlightSearch.previewResults([]).isEmpty)
    }

    func testMoreResultsNavigationPreservesQueryAndOnlySelectsVisibleRows() throws {
        let actions = (1...6).map { makeAction("Overflow \($0)") }
        let search = makeSearch(actions)
        defer { search.stop() }
        search.text = "Overflow"
        XCTAssertEqual(search.results.map(\.id), ["action:Overflow 1", "action:Overflow 2", "action:Overflow 3", "more:actions", "text-actions"])
        search.moveSelection(3)
        guard case .more(let group) = try XCTUnwrap(search.selectedResult).content else { return XCTFail("Expected More Results") }
        search.chooseGroup(group)
        XCTAssertEqual(search.text, "Overflow")
        XCTAssertEqual(search.searchGroup, .actions)
        XCTAssertEqual(search.results.map(\.id), actions.map { "action:" + $0.actionMeta.identifier })
        search.moveSelection(4)
        XCTAssertEqual(search.selectedResult?.id, "action:Overflow 5")
        search.chooseAction(actions[4])
        search.text = "Actual input"
        search.backToSearch()
        XCTAssertEqual(search.searchGroup, .actions)
        XCTAssertEqual(search.text, "Overflow")
        search.backToSearch()
        XCTAssertNil(search.searchGroup)
        XCTAssertEqual(search.text, "Overflow")
        XCTAssertEqual(search.selectedResult?.id, "more:actions")
        search.moveSelection(1)
        XCTAssertEqual(search.selectedResult?.id, "text-actions")
        search.text = "Overflow 6"
        XCTAssertEqual(search.results.map(\.id), ["action:Overflow 6", "text-actions"])
    }

    func testScopedSearchKeepsItsScopeAndHandlesLongOrUnmatchedQueries() {
        let title = String(repeating: "Long action name ", count: 6)
        let search = makeSearch([makeAction(title)])
        defer { search.stop() }
        search.text = "Long"
        search.chooseGroup(.actions)
        search.text = title
        XCTAssertEqual(search.selectedResult?.id, "action:" + title)
        search.text = "No matches"
        XCTAssertEqual(search.searchGroup, .actions)
        XCTAssertTrue(search.results.isEmpty)
        XCTAssertNil(search.selectedResult)
        search.backToSearch()
        XCTAssertEqual(search.text, "No matches")
        XCTAssertEqual(search.selectedResult?.id, "text-actions")
    }

    func testClipboardSearchFindsTextLinksEncodedFileNamesAndImageOCR() throws {
        let model = PersistenceController.shared.container.managedObjectModel
        let container = NSPersistentContainer(name: "ClipHistory", managedObjectModel: model)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("spotlight-clips-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: directory.appendingPathComponent("history.sqlite"))]
        let controller = PersistenceController(container: container)
        let context = controller.container.viewContext
        defer {
            context.reset()
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
        }
        let values: [(String?, String?, NSPasteboard.PasteboardType, String)] = [
            ("A long note\nwith the 项目报告 keyword inside", nil, .string, "original text"),
            (nil, "https://example.com/项目报告", .URL, "https://example.com/项目报告"),
            (nil, URL(fileURLWithPath: "/tmp/项目报告 final.pdf").absoluteString, .fileURL, URL(fileURLWithPath: "/tmp/项目报告 final.pdf").absoluteString),
            ("项目报告 recognized from an image", nil, .png, "image bytes"),
            ("Unrelated content", nil, .string, "Unrelated content")
        ]
        for (index, value) in values.enumerated() {
            let clip = ClipHistoryData(context: context)
            clip.application = "selected.tests"
            clip.plainText = value.0
            clip.url = value.1
            clip.lastCopiedAt = Date(timeIntervalSince1970: Double(index))
            let representation = ClipHistoryItem(context: context)
            representation.type = value.2.rawValue
            representation.data = Data(value.3.utf8)
            clip.addToItems(representation)
        }
        try context.save()
        let results = try SpotlightSearch.clipboardMatches("项目报告", in: context)
        XCTAssertEqual(results.count, 4)
        XCTAssertTrue(results.allSatisfy { $0.group == .clipboard && $0.url == nil })
        let clips = results.compactMap { item -> ClipHistoryData? in
            if case .clipboard(let clip) = item.content { return clip }
            return nil
        }
        XCTAssertEqual(clips.map(\.lastCopiedAt), [3, 2, 1, 0].map { Date(timeIntervalSince1970: Double($0)) })
        XCTAssertEqual(clips.first?.getItems().first?.data, Data("image bytes".utf8))
        XCTAssertTrue(try SpotlightSearch.clipboardMatches("*", in: context).isEmpty)
        XCTAssertTrue(try SpotlightSearch.clipboardMatches("", in: context).isEmpty)
        XCTAssertEqual(try SpotlightSearch.clipboardMatches("FINAL", in: context).count, 1)
    }

    func testClipboardSearchLimitsResultsAndRestoresRichFormats() throws {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: PersistenceController.shared.container.managedObjectModel)
        try context.persistentStoreCoordinator?.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        for index in 0..<25 {
            let clip = ClipHistoryData(context: context)
            clip.application = "selected.tests"
            clip.plainText = "Café \(index)"
            clip.lastCopiedAt = Date(timeIntervalSince1970: Double(index))
            for (type, value) in [(NSPasteboard.PasteboardType.string, "Café \(index)"), (.html, "<b>Café \(index)</b>")] {
                let representation = ClipHistoryItem(context: context)
                representation.type = type.rawValue
                representation.data = Data(value.utf8)
                clip.addToItems(representation)
            }
        }
        try context.save()
        let results = try SpotlightSearch.clipboardMatches("CAFE", in: context)
        XCTAssertEqual(results.count, 20)
        XCTAssertEqual(results.first?.title, "Café 24")
        guard case .clipboard(let clip) = try XCTUnwrap(results.first).content else { return XCTFail("Expected a clipboard result") }
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        ClipService(pasteboard: pasteboard).restore(clip) {
            XCTAssertEqual(pasteboard.string(forType: .string), "Café 24")
            XCTAssertEqual(pasteboard.string(forType: .html), "<b>Café 24</b>")
        }
    }

    private func makeSearch(_ actions: [PerformAction]) -> SpotlightSearch {
        SpotlightSearch(allActions: actions, bundleID: "test.app", configuration: configuration)
    }

    private func makeAction(_ title: String) -> PerformAction {
        PerformAction(actionMeta: GenericAction(title: title, icon: "symbol:star", identifier: title), complete: { _ in })
    }

    private func item(_ title: String) -> SpotlightItem {
        SpotlightItem(id: title, title: title, subtitle: "", content: .application(URL(fileURLWithPath: "/Applications/\(title).app")))
    }
}
