import Foundation
import AppKit
import os

let SelfBundleID = Bundle.main.bundleIdentifier ?? "io.kitool.Selected"

let logger = Logger(subsystem: SelfBundleID, category: "")

enum AppRuntimeMode {
    case normal, preview, tests

    static var current: Self {
        detect(environment: ProcessInfo.processInfo.environment,
               testBundleLoaded: NSClassFromString("XCTestCase") != nil)
    }

    static func detect(environment: [String: String], testBundleLoaded: Bool = false) -> Self {
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1" {
            return .preview
        }
        if testBundleLoaded || environment["SELECTED_TESTING"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil {
            return .tests
        }
        return .normal
    }
}

var isPreview: Bool { AppRuntimeMode.current == .preview }

let kExpandedLength: CGFloat = 100
