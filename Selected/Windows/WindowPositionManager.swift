//
//  WindowPositionManager.swift
//  Selected
//
//  Created by sake on 14/12/25.
//

import Foundation
import SwiftUI

class WindowPositionManager {
    let key :String

    init(key: String) {
        self.key = key
    }

    struct Saved: Codable {
        var sizeW: CGFloat
        var sizeH: CGFloat
        // window center relative to screen.visibleFrame (0~1)
        var centerRX: CGFloat
        var centerRY: CGFloat
    }

    func storePosition(of window: NSWindow) {
        guard let screen = window.screen else { return }
        let vf = screen.visibleFrame
        let wf = window.frame

        let center = CGPoint(x: wf.midX, y: wf.midY)
        let rx = (center.x - vf.minX) / vf.width
        let ry = (center.y - vf.minY) / vf.height

        let saved = Saved(
            sizeW: wf.width,
            sizeH: wf.height,
            centerRX: rx,
            centerRY: ry
        )

        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    @MainActor
    func restorePosition(for window: NSWindow) -> Bool {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let saved = try? JSONDecoder().decode(Saved.self, from: data)
        else { return false }

        // 目标屏幕：鼠标所在屏幕
        let targetScreen = Self.screenContainingMouse() ?? NSScreen.main
        guard let screen = targetScreen else { return false }

        let vf = screen.visibleFrame

        // 恢复 size
        let size = NSSize(
            width: saved.sizeW,
            height:saved.sizeH,
        )

        // 把相对中心点映射回目标屏幕
        let cx = vf.minX + vf.width  * saved.centerRX
        let cy = vf.minY + vf.height * saved.centerRY

        var origin = NSPoint(x: cx - size.width / 2, y: cy - size.height / 2)

        // clamp：确保窗口完全落在 visibleFrame 内
        origin.x = min(max(origin.x, vf.minX), vf.maxX - size.width)
        origin.y = min(max(origin.y, vf.minY), vf.maxY - size.height)

        let frame = NSRect(origin: origin, size: size)
        window.setFrame(frame, display: true)

        return true
    }

    private static func screenContainingMouse() -> NSScreen? {
        // 全局坐标（左下角为原点）
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) })
    }
}
