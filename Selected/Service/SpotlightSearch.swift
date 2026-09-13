import AppKit
import CoreData
import Observation

@MainActor @Observable final class SpotlightSearch: NSObject {
    enum Mode {
        case search, textActions, action(PerformAction)
    }

    var text = "" { didSet { refresh() } }
    var selectedID: String?
    private(set) var mode: Mode = .search
    private(set) var searchGroup: SpotlightItem.Group?
    private(set) var results: [SpotlightItem] = []
    private(set) var isSearchingFiles = false
    private(set) var fileSearchFailed = false
    private(set) var clipboardSearchFailed = false
    private(set) var applications: [SpotlightItem] = []
    private let allActions: [PerformAction]
    private let bundleID: String
    private let configuration: UserConfiguration
    private var previousSearch = ""
    private var files: [SpotlightItem] = []
    private var clipboard: [SpotlightItem] = []
    @ObservationIgnored private var query: NSMetadataQuery?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(allActions: [PerformAction], bundleID: String,
         configuration: UserConfiguration = ConfigurationManager.shared.userConfiguration) {
        self.allActions = allActions
        self.bundleID = bundleID
        self.configuration = configuration
        super.init()
    }

    var isSearchMode: Bool {
        if case .search = mode { return true }
        return false
    }

    var context: SelectedTextContext { ActionInput.textContext(text, bundleID: bundleID) }

    var selectedResult: SpotlightItem? {
        if let selected = results.first(where: { $0.id == selectedID }) { return selected }
        if isSearchMode, searchGroup == nil, prefersTextActions { return results.first { $0.id == "text-actions" } }
        return results.first
    }

    var prefersTextActions: Bool { text.contains(where: \.isNewline) || text.count > 80 }

    func moveSelection(_ offset: Int) {
        guard !results.isEmpty else { return }
        let index = results.firstIndex { $0.id == selectedResult?.id } ?? 0
        selectedID = results[min(max(index + offset, 0), results.count - 1)].id
    }

    func chooseAction(_ action: PerformAction) {
        previousSearch = text
        mode = .action(action)
        text = ""
    }

    func chooseTextActions() {
        previousSearch = text
        mode = .textActions
        refresh()
    }

    func chooseGroup(_ group: SpotlightItem.Group) {
        searchGroup = group
        selectedID = nil
        rebuildResults()
    }

    func backToSearch() {
        if isSearchMode {
            let group = searchGroup
            searchGroup = nil
            rebuildResults()
            selectedID = group.map { SpotlightItem.more($0).id }
            return
        }
        mode = .search
        text = previousSearch
    }

    func loadApplications() async {
        let installed = await Task.detached(priority: .userInitiated) { Self.installedApplications() }.value
        guard !Task.isCancelled else { return }
        var byURL = Dictionary(installed.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let url = app.bundleURL, let name = app.localizedName else { continue }
            let id = "app:" + url.path
            byURL[id] = SpotlightItem(id: id, title: name, subtitle: url.deletingLastPathComponent().path,
                                      content: .application(url), searchNames: [url.deletingPathExtension().lastPathComponent])
        }
        applications = Array(byURL.values)
        rebuildResults()
    }

    func stop() {
        searchTask?.cancel()
        searchTask = nil
        if let query {
            query.stop()
            NotificationCenter.default.removeObserver(self, name: nil, object: query)
        }
        query = nil
        isSearchingFiles = false
    }

    private func refresh() {
        stop()
        files = []
        clipboard = []
        selectedID = nil
        fileSearchFailed = false
        clipboardSearchFailed = false
        rebuildResults()
        let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSearchMode, !term.isEmpty else { return }
        isSearchingFiles = !prefersTextActions
        searchTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(180)) }
            catch { return }
            guard let self else { return }
            do {
                clipboard = try Self.clipboardMatches(term, in: PersistenceController.shared.container.viewContext)
            } catch {
                clipboardSearchFailed = true
                AppLogger.clipboard.error("Spotlight search: \(error)")
            }
            rebuildResults()
            if !prefersTextActions { searchFiles(term) }
        }
    }

    private func rebuildResults() {
        let term = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .search:
            guard !term.isEmpty else { results = []; return }
            let actions = allActions.filter { action in
                let meta = action.actionMeta
                return (meta.requiredApps?.isEmpty != false || meta.requiredApps?.contains(bundleID) == true)
                    && meta.excludedApps?.contains(bundleID) != true
            }.map(SpotlightItem.action)
            let matches = Self.ranked(applications, matching: term, limit: 8)
                + Self.ranked(actions, matching: term, limit: 8) + files + clipboard
            if let searchGroup {
                results = matches.filter { $0.group == searchGroup }
            } else {
                results = Self.previewResults(matches)
                let textEntry = SpotlightItem(id: "text-actions", title: String(localized: "Actions for Input Text"),
                                              subtitle: text, content: .textActions)
                results.append(textEntry)
            }
        case .textActions:
            results = term.isEmpty ? [] : textActions().map(SpotlightItem.action)
        case .action(let action):
            results = FilterActions(context, list: [action]).contains { $0.actionMeta.identifier == action.actionMeta.identifier }
                ? [SpotlightItem.action(action)] : []
        }
        var seen = Set<String>()
        results = results.filter { seen.insert($0.id).inserted }
    }

    private func textActions() -> [PerformAction] {
        GetActions(ctx: context, from: allActions, configuration: configuration)
    }

    static func previewResults(_ items: [SpotlightItem]) -> [SpotlightItem] {
        let grouped = Dictionary(grouping: items, by: \.group)
        return SpotlightItem.Group.allCases.flatMap { group in
            let matches = grouped[group] ?? []
            return Array(matches.prefix(3)) + (matches.count > 3 ? [.more(group)] : [])
        }
    }

    static func ranked(_ items: [SpotlightItem], matching term: String, limit: Int) -> [SpotlightItem] {
        items.compactMap { item in item.matchScore(term).map { (item, $0) } }
            .sorted {
                if $0.1 != $1.1 { return $0.1 < $1.1 }
                let order = $0.0.title.localizedStandardCompare($1.0.title)
                return order == .orderedSame ? $0.0.id < $1.0.id : order == .orderedAscending
            }
            .prefix(limit).map(\.0)
    }

    nonisolated static func installedApplications(in directories: [URL] = [
        URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    ]) -> [SpotlightItem] {
        var items: [SpotlightItem] = []
        for directory in directories {
            guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.localizedNameKey],
                                                                 options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                let name = (try? url.resourceValues(forKeys: [.localizedNameKey]))?.localizedName
                    ?? url.deletingPathExtension().lastPathComponent
                items.append(SpotlightItem(id: "app:" + url.path,
                                           title: name.hasSuffix(".app") ? String(name.dropLast(4)) : name,
                                           subtitle: (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath,
                                           content: .application(url), searchNames: [url.deletingPathExtension().lastPathComponent]))
            }
        }
        return items
    }

    static func filePredicate(_ term: String) -> NSPredicate {
        NSPredicate(format: "%K CONTAINS[cd] %@ AND NOT (%K == %@)",
                    "kMDItemFSName", term, "kMDItemContentType", "com.apple.application-bundle")
    }

    static func clipboardMatches(_ term: String, in context: NSManagedObjectContext) throws -> [SpotlightItem] {
        guard !term.isEmpty else { return [] }
        let request = NSFetchRequest<ClipHistoryData>(entityName: "ClipHistoryData")
        let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? term
        request.predicate = NSPredicate(format: "plainText CONTAINS[cd] %@ OR url CONTAINS[cd] %@ OR url CONTAINS[cd] %@",
                                        term, term, encoded)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipHistoryData.lastCopiedAt, ascending: false)]
        request.fetchLimit = 20
        return try context.fetch(request).map(SpotlightItem.clipboard)
    }

    private func searchFiles(_ term: String) {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.predicate = Self.filePredicate(term)
        query.notificationBatchingInterval = 0.2
        for name in [NSNotification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            NotificationCenter.default.addObserver(self, selector: #selector(receiveFiles(_:)), name: name, object: query)
        }
        self.query = query
        if !query.start() {
            stop()
            fileSearchFailed = true
        }
    }

    @objc private func receiveFiles(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery, query === self.query else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }
        var candidates: [SpotlightItem] = []
        let excludedDirectories = ["/System/", "/Library/", "/private/",
                                   FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library").path + "/"]
        for index in 0..<query.resultCount {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: "kMDItemPath") as? String else { continue }
            let url = URL(fileURLWithPath: path)
            guard !excludedDirectories.contains(where: path.hasPrefix),
                  !url.pathComponents.contains(where: { $0.hasPrefix(".") || $0.lowercased().hasSuffix(".app") }) else { continue }
            candidates.append(.file(url))
        }
        files = Self.ranked(candidates, matching: text.trimmingCharacters(in: .whitespacesAndNewlines), limit: 30)
            .filter { item in
                guard let url = item.url else { return false }
                return (try? url.resourceValues(forKeys: [.isHiddenKey]))?.isHidden == false
            }
            .prefix(20).map { $0 }
        if notification.name == .NSMetadataQueryDidFinishGathering { isSearchingFiles = false }
        rebuildResults()
    }
}
