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
        let saved = Saved(frame: window.frame, screenFrame: screen.visibleFrame)

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

        window.setFrame(saved.frame(in: screen.visibleFrame), display: true)

        return true
    }

    private static func screenContainingMouse() -> NSScreen? {
        // 全局坐标（左下角为原点）
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) })
    }
}

extension WindowPositionManager.Saved {
    init(frame: NSRect, screenFrame: NSRect) {
        sizeW = frame.width
        sizeH = frame.height
        centerRX = (frame.midX - screenFrame.minX) / screenFrame.width
        centerRY = (frame.midY - screenFrame.minY) / screenFrame.height
    }

    func frame(in screenFrame: NSRect) -> NSRect {
        let size = NSSize(width: sizeW, height: sizeH)
        let center = NSPoint(x: screenFrame.minX + screenFrame.width * centerRX,
                             y: screenFrame.minY + screenFrame.height * centerRY)
        let origin = NSPoint(x: min(max(center.x - size.width / 2, screenFrame.minX), screenFrame.maxX - size.width),
                             y: min(max(center.y - size.height / 2, screenFrame.minY), screenFrame.maxY - size.height))
        return NSRect(origin: origin, size: size)
    }
}
