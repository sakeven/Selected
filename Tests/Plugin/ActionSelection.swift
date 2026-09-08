import AppKit
import Testing
@testable import Selected

struct ActionSelectionTests {
    @Test func URLOverridesApplicationAndPreservesConfiguredOrder() {
        let configuration = UserConfiguration(defaultActions: ["default"], appConditions: [.init(bundleID: "app", actions: ["a"])], urlConditions: [.init(url: "example.com", actions: ["b", "missing", "a", "b"])])
        let context = SelectedTextContext(Text: "text", BundleID: "app", WebPageURL: "https://example.com/path")
        let actions = [action("a"), action("b"), action("default")]
        #expect(GetActions(ctx: context, from: actions, configuration: configuration).map(\.actionMeta.identifier) == ["b", "a", "b"])
        #expect(GetActions(ctx: SelectedTextContext(Text: "text", BundleID: "app"), from: actions, configuration: configuration).map(\.actionMeta.identifier) == ["a"])
        #expect(GetActions(ctx: SelectedTextContext(Text: "text"), from: actions, configuration: configuration).map(\.actionMeta.identifier) == ["default"])
    }

    @Test func emptyRuleStillUsesAllActionsAndAddsContextualBuiltins() {
        let configuration = UserConfiguration(defaultActions: [], appConditions: [], urlConditions: [])
        var context = SelectedTextContext(Text: "text")
        context.URLs = ["https://example.com"]
        context.Address = "Paris"
        let actions = [action("a"), action("b")]
        #expect(GetActions(ctx: context, from: actions, configuration: configuration).map(\.actionMeta.identifier) == ["a", "b", "selected.openlinks", "selected.map"])
    }

    @Test func filtersKeepSupportedPredicateRequirementsAndEditableRules() {
        let visible = action("visible")
        let unsupported = action("unsupported")
        unsupported.supported = { _ in false }
        let paste = action("paste", after: .paste)
        let needsURL = action("url")
        needsURL.actionMeta.requirements = [.url]
        #expect(FilterActions(SelectedTextContext(Text: "text"), list: [visible, unsupported, paste, needsURL]).map(\.actionMeta.identifier) == ["visible"])
        var editable = SelectedTextContext(Text: "text")
        editable.Editable = true
        #expect(FilterActions(editable, list: [paste]).map(\.actionMeta.identifier) == ["paste"])
    }

    @Test func duplicateActionIDsStillSelectTheLastDefinition() {
        let first = action("same"), last = action("same")
        last.actionMeta.title = "last"
        let configuration = UserConfiguration(defaultActions: ["same"], appConditions: [], urlConditions: [])
        let result = GetActions(ctx: SelectedTextContext(Text: "text"), from: [first, last], configuration: configuration)
        #expect(result.count == 1)
        #expect(result.first === last)
    }

    private func action(_ id: String, after: AfterAction? = nil) -> PerformAction {
        PerformAction(actionMeta: GenericAction(title: id, icon: "symbol:star", after: after, identifier: id), complete: { _ in })
    }
}
