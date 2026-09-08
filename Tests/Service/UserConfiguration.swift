import Foundation
import Testing
@testable import Selected

struct UserConfigurationTests {
    @Test func applicationRulesUseFirstExactMatchBeforeDefaults() {
        let configuration = UserConfiguration(defaultActions: ["default"], appConditions: [
            AppCondition(bundleID: "test.app", actions: []),
            AppCondition(bundleID: "test.app", actions: ["ignored duplicate"])
        ], urlConditions: [])
        #expect(configuration.appCondition(bundleID: "test.app")?.actions == [])
        #expect(configuration.appCondition(bundleID: "test.app.other")?.actions == ["default"])
        #expect(configuration.appCondition(bundleID: "other")?.bundleID == "other")
        #expect(UserConfiguration(defaultActions: [], appConditions: [], urlConditions: []).appCondition(bundleID: "other") == nil)
    }

    @Test func URLRulesKeepOrderedCaseSensitiveSubstringMatching() {
        let configuration = UserConfiguration(defaultActions: [], appConditions: [], urlConditions: [
            URLCondition(url: "example.com", actions: ["first"]),
            URLCondition(url: "example.com/path", actions: ["second"])
        ])
        #expect(configuration.urlCondition(url: "https://example.com/path")?.actions == ["first"])
        #expect(configuration.urlCondition(url: "https://EXAMPLE.com/path") == nil)
        #expect(configuration.urlCondition(url: "https://other.com") == nil)
    }

    @Test func diskRoundTripKeepsExistingSchemaAndOrder() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("configuration-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("UserConfiguration.json")
        let manager = ConfigurationManager(fileURL: file)
        manager.userConfiguration = UserConfiguration(defaultActions: ["b", "a"], appConditions: [.init(bundleID: "test", actions: ["c"])], urlConditions: [.init(url: "example", actions: ["d"])])
        manager.saveConfiguration()
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        #expect(Set(json.keys) == ["defaultActions", "appConditions", "urlConditions"])
        #expect((json["appConditions"] as? [[String: Any]])?.first?["bundleID"] as? String == "test")
        let loaded = ConfigurationManager(fileURL: file)
        #expect(loaded.userConfiguration.defaultActions == ["b", "a"])
        #expect(loaded.getAppCondition(bundleID: "test")?.actions == ["c"])
        #expect(loaded.getURLCondition(url: "https://example.com")?.actions == ["d"])
        try Data("invalid".utf8).write(to: file)
        loaded.loadConfiguration()
        #expect(loaded.userConfiguration.defaultActions == ["b", "a"])
        try FileManager.default.removeItem(at: file)
        loaded.loadConfiguration()
        #expect(loaded.userConfiguration.defaultActions == ["b", "a"])
    }
}
