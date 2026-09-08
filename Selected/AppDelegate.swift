import SwiftUI
import Accessibility
import Defaults

class AppDelegate: NSObject, NSApplicationDelegate {
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AppRuntimeMode.current != .tests else { return }
        if isPreview {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PreviewHostView())
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            previewWindow = window
            return
        }

        do { try APIKeyStore.shared.migrateLegacyValues() }
        catch { logger.error("API credential migration failed: \(error.localizedDescription)") }

        if let model = OpenAIModelMigration.chatReplacement(for: Defaults[.openAIModel]) {
            Defaults[.openAIModel] = model
        }
        if let model = OpenAIModelMigration.translationReplacement(for: Defaults[.openAITranslationModel]) {
            Defaults[.openAITranslationModel] = model
        }

        setDefaultAppForCustomFileType()
        // 不需要主窗口，不需要显示在 dock 上
        NSApp.setActivationPolicy(NSApplication.ActivationPolicy.accessory)
        requestAccessibilityPermissions()

        DispatchQueue.main.async {
            PersistenceController.shared.startDailyTimer()
        }

        PluginManager.shared.loadPlugins()
        ConfigurationManager.shared.loadConfiguration()
        DispatchQueue.main.async {
            monitorMouseMove()
        }
        DispatchQueue.main.async {
            let clipboard = ClipService.shared
            ClipWindowManager.shared.startMonitoring()
            clipboard.startMonitoring()
        }

        DispatchQueue.main.async {
            ClipboardHotKeyManager.shared.registerHotKey()
            SpotlightHotKeyManager.shared.registerHotKey()
        }

        // 注册空间改变通知
        // 这里不能使用 NotificationCenter.default.
        NSWorkspace.shared.notificationCenter.addObserver(self,
                                                          selector: #selector(spaceDidChange),
                                                          name: NSWorkspace.activeSpaceDidChangeNotification,
                                                          object: nil)
    }

    @objc func spaceDidChange() {
        // 当空间改变时触发
        ClipWindowManager.shared.forceCloseWindow()
        ChatWindowManager.shared.closeAllWindows(.force)
        SpotlightWindowManager.shared.forceCloseWindow()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            // 处理打开的文件
            logger.debug("\(url.path)")
            do {
                try PluginManager.shared.install(url: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = String(localized: "Plugin Installation Failed")
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        guard AppRuntimeMode.current == .normal else { return }
        // 当 app 变为活跃时关闭全局热键
        ClipboardHotKeyManager.shared.unregisterHotKey()
        SpotlightHotKeyManager.shared.unregisterHotKey()
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard AppRuntimeMode.current == .normal else { return }
        if Defaults[.enableClipboard] {
            // 当 app 退到后台时开启全局热键
            ClipboardHotKeyManager.shared.registerHotKey()
        }
        SpotlightHotKeyManager.shared.registerHotKey()
    }
}


func setDefaultAppForCustomFileType() {
    let customUTI = "io.kitool.selected.ext"
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "io.kitool.Selected"
    logger.info("bundleIdentifier \(bundleIdentifier)")

    LSSetDefaultRoleHandlerForContentType(customUTI as CFString, .editor, bundleIdentifier as CFString)
}


func requestAccessibilityPermissions() {
    guard AppRuntimeMode.current == .normal else { return }
    // 判断权限
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let accessEnabled = AXIsProcessTrustedWithOptions(options)

    logger.info("accessEnabled: \(accessEnabled)")

    if !accessEnabled {
        // 请求权限
        // 注意不能是 sandbox，否则辅助功能里无法看到这个 app
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
