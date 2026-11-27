//
//  WindowManager.swift
//  Selected
//
//  Created by sake on 2024/3/18.
//

import Foundation
import SwiftUI

// MARK: - 窗口类型枚举
enum WindowType {
    case popBar
    case translation
    case tts
    case text
}

// MARK: - 窗口控制器协议
protocol WindowCtr: NSObjectProtocol {
    func canClose() -> Bool
    func close()
    func frame() -> NSRect
    func showWindow(_ sender: Any?)
    func isPopbar() -> Bool
    var window: NSWindow? { get }
    var onClose: (()->Void)? { get set }
}

// MARK: - 基础窗口控制器
class BaseWindowController: NSWindowController, NSWindowDelegate, WindowCtr {

    var onClose: (()->Void)?
    var pinnedModel: PinnedModel
    // When in showing SharingPicker, we should avoid close popbar window by accident.
    var showingSharingPicker = ShowingSharingPickerModel()


    private var windowType: WindowType


    func frame() -> NSRect {
        return window?.frame ?? .zero
    }

    func isPopbar() -> Bool {
        return windowType == .popBar
    }

    init(rootView: AnyView, windowType: WindowType,
         positionStrategy: WindowPositionStrategy,
         size: NSSize,
         isKey: Bool = false, alpha: CGFloat = 1.0) {
        self.windowType = windowType

        // 创建窗口
        let window = FloatingPanel(
            contentRect: .init(x: 0, y: 0, width: size.width, height: size.height),
            backing: .buffered,
            defer: false,
            key: isKey
        )

        window.alphaValue = alpha
        if alpha == 1.0 {
            window.isOpaque = windowType != .popBar && windowType != .text
            window.backgroundColor = .clear
        }
        pinnedModel = PinnedModel()

        super.init(window: window)

        window.level = .screenSaver
        let view = rootView.environmentObject(pinnedModel).environmentObject(showingSharingPicker)
        let contentView = NSHostingView(rootView: view)
        window.contentView = contentView
        if size == .zero { window.setContentSize(contentView.fittingSize) }
        window.delegate = self
        // 根据策略定位窗口
        positionWindow(using: positionStrategy, windowSize: size)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func positionWindow(using strategy: WindowPositionStrategy, windowSize: NSSize) {
        let screenPoint: NSPoint
        if case .nearPoint(let point) = strategy {
            screenPoint = point
        } else {
            screenPoint = NSEvent.mouseLocation
        }
        guard let window,
              let screen = NSScreen.screens.first(where: { NSMouseInRect(screenPoint, $0.frame, false) }) else {
            return
        }
        window.setFrameOrigin(strategy.origin(windowFrame: window.frame, requestedSize: windowSize, screenFrame: screen.visibleFrame))
    }

    func canClose() -> Bool {
        return !pinnedModel.pinned && !showingSharingPicker.showing
    }

    func windowDidResignActive(_ notification: Notification) {
        if canClose() {
            self.close()
        }
    }

    override func close() {
        super.close()
        onClose?()
    }
}

// MARK: - 特化的窗口控制器
class PopBarWindowController: BaseWindowController {
    let context: SelectedTextContext
    let selectionPoint: NSPoint

    init(context: SelectedTextContext, at point: NSPoint, onClick: @escaping () -> Void) {
        self.context = context
        selectionPoint = point
        let view = PopBarView(actions: GetActions(ctx: context), ctx: context, resultPosition: point, onClick: onClick)
        super.init(rootView: AnyView(view), windowType: .popBar, positionStrategy: .nearPoint(point), size: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TranslationWindowController: BaseWindowController {
    init(rootView: AnyView) {
        super.init(rootView: rootView, windowType: .translation, positionStrategy: .centerScreenOffset(0.75), size: .init(width: 550, height: 450), isKey: true)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TTSWindowController: BaseWindowController {
    private let session: SpeechSession

    init(session: SpeechSession, onClose: @escaping () -> Void) {
        self.session = session
        let view = AudioPlayerView(session: session, onClose: onClose)
        super.init(rootView: AnyView(view), windowType: .tts, positionStrategy: .centerScreen, size: .zero)
        window?.styleMask = [.borderless, .nonactivatingPanel]
        window?.isOpaque = false
        window?.hasShadow = true
        window?.hidesOnDeactivate = false
        (window as? FloatingPanel)?.key = true
    }

    override func canClose() -> Bool { false }

    override func close() {
        session.stop()
        super.close()
    }

    func windowWillClose(_ notification: Notification) {
        session.stop()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TextWindowController: BaseWindowController {
    init(text: String, editable: Bool, at point: NSPoint = NSEvent.mouseLocation) {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let view = PopResultView(text: text, editable: editable, maximumHeight: min(320, (screen?.visibleFrame.height ?? 600) - 80))
        super.init(rootView: AnyView(view), windowType: .text, positionStrategy: .nearPoint(point), size: .zero, isKey: true)
        window?.styleMask.remove(.resizable)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - 窗口管理器
@MainActor class WindowManager {
    static let shared = WindowManager()

    let mouseLocation: () -> NSPoint
    private var windowCtrs = [WindowCtr]()
    private var speechWindowController: TTSWindowController?
    private var pendingPopBar: (area: NSRect, bundleID: String, task: Task<Void, Never>)?
    private var visiblePopBar: PopBarWindowController? {
        windowCtrs.last { $0.isPopbar() && $0.window?.isVisible == true } as? PopBarWindowController
    }

    init(mouseLocation: @escaping () -> NSPoint = { NSEvent.mouseLocation }) {
        self.mouseLocation = mouseLocation
    }

    // MARK: - Public API

    func schedulePopBar(_ ctx: SelectedTextContext, at point: NSPoint) {
        pendingPopBar?.task.cancel()
        pendingPopBar = nil
        if let visiblePopBar, visiblePopBar.context == ctx, visiblePopBar.selectionPoint == point { return }

        let area = NSRect(origin: point, size: .zero).insetBy(dx: -kExpandedLength, dy: -kExpandedLength)
        // Wait for a possible third click to finish selecting the line.
        let task = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(200)) }
            catch { return }
            guard let self, !Task.isCancelled else { return }
            pendingPopBar = nil
            guard area.contains(mouseLocation()),
                  visiblePopBar?.showingSharingPicker.showing != true else { return }
            createPopBarWindow(ctx, at: point)
        }
        pendingPopBar = (area, ctx.BundleID, task)
    }

    func createPopBarWindow(_ ctx: SelectedTextContext, at point: NSPoint = NSEvent.mouseLocation) {
        let controller = PopBarWindowController(context: ctx, at: point) { [weak self] in
            self?.closeOnlyPopbarWindows(.force)
        }
        createWindow(controller)
    }

    func frontmostApplicationDidChange(to bundleID: String?) {
        if let source = pendingPopBar?.bundleID ?? visiblePopBar?.context.BundleID, source != bundleID {
            closeOnlyPopbarWindows(.force)
        }
    }

    func createTranslationWindow(withText text: String, to: String) {
        let contentView = TranslationView(text: text, to: to)
        let windowController = TranslationWindowController(rootView: AnyView(contentView))
        createWindow(windowController)
    }

    func showSpeechWindow(session: SpeechSession) {
        _ = closeOnlyPopbarWindows(.force)
        if speechWindowController == nil {
            let controller = TTSWindowController(session: session) { [weak self] in self?.closeSpeechWindow() }
            controller.onClose = { [weak self] in self?.speechWindowController = nil }
            speechWindowController = controller
        }
        speechWindowController?.window?.orderFrontRegardless()
    }

    func closeSpeechWindow() {
        speechWindowController?.close()
    }

    func createTextWindow(_ text: String, editable: Bool, at point: NSPoint = NSEvent.mouseLocation) {
        createWindow(TextWindowController(text: text, editable: editable, at: point))
    }

    @discardableResult func closeOnlyPopbarWindows(_ mode: CloseWindowMode) -> Bool {
        closeWindows(mode, onlyPopBars: true)
    }

    func closeAllWindows(_ mode: CloseWindowMode) {
        _ = closeWindows(mode, onlyPopBars: false)
    }

    private func closeWindows(_ mode: CloseWindowMode, onlyPopBars: Bool) -> Bool {
        if let pendingPopBar, mode != .expanded || !pendingPopBar.area.contains(mouseLocation()) {
            pendingPopBar.task.cancel()
            self.pendingPopBar = nil
        }
        let previousCount = windowCtrs.count
        for index in windowCtrs.indices.reversed() {
            let controller = windowCtrs[index]
            if (!onlyPopBars || controller.isPopbar()) && closeWindow(mode, windowCtr: controller) {
                windowCtrs.remove(at: index)
            }
        }
        return windowCtrs.count < previousCount
    }

    // MARK: - Private methods
    
    private func createWindow(_ windowController: WindowCtr) {
        closeAllWindows(.force)
        windowController.showWindow(nil)
        windowCtrs.append(windowController)

        // 添加窗口关闭通知观察者
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: windowController.window,
            queue: nil
        ) {  _ in }
    }

    private func closeWindow(_ mode: CloseWindowMode, windowCtr: WindowCtr) -> Bool {
        guard mode.shouldClose(frame: windowCtr.frame(), mouseLocation: mouseLocation()),
              windowCtr.canClose() else { return false }
        windowCtr.close()
        return true
    }
}
