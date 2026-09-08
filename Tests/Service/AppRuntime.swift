import AppKit
import Testing
@testable import Selected

struct AppRuntimeTests {
    @Test func normalLaunchKeepsSystemIntegrationEnabled() {
        #expect(AppRuntimeMode.detect(environment: [:]) == .normal)
        #expect(AppRuntimeMode.detect(environment: ["XCODE_RUNNING_FOR_PREVIEWS": "0", "SELECTED_TESTING": "0"]) == .normal)
    }

    @Test func previewsAndPlaygroundsUsePreviewMode() {
        #expect(AppRuntimeMode.detect(environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]) == .preview)
        #expect(AppRuntimeMode.detect(environment: ["XCODE_RUNNING_FOR_PLAYGROUNDS": "1"]) == .preview)
        #expect(AppRuntimeMode.detect(environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"], testBundleLoaded: true) == .preview)
    }

    @Test func unitTestsAndUITestLaunchesUseTestMode() {
        #expect(AppRuntimeMode.detect(environment: [:], testBundleLoaded: true) == .tests)
        #expect(AppRuntimeMode.detect(environment: ["XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration"]) == .tests)
        #expect(AppRuntimeMode.detect(environment: ["SELECTED_TESTING": "1"]) == .tests)
        #expect(AppRuntimeMode.current == .tests)
    }

    @Test @MainActor func testHostSkipsStartupAndActivationSideEffects() {
        let delegate = AppDelegate()
        let windows = Set(NSApp.windows.map(\.windowNumber))
        let activationPolicy = NSApp.activationPolicy()
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        delegate.applicationWillBecomeActive(Notification(name: NSApplication.willBecomeActiveNotification))
        delegate.applicationDidResignActive(Notification(name: NSApplication.didResignActiveNotification))
        requestAccessibilityPermissions()
        #expect(Set(NSApp.windows.map(\.windowNumber)) == windows)
        #expect(NSApp.activationPolicy() == activationPolicy)
    }
}
