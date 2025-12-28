//
//  AppLogger.swift
//  Selected
//
//  Created by sake on 28/12/25.
//

import os

enum AppLogger {
    static let clipboard = Logger(
        subsystem: SelfBundleID,
        category: "Clipboard"
    )

    static let ai = Logger(
        subsystem: SelfBundleID,
        category: "AI"
    )

    static let plugin = Logger(
        subsystem: SelfBundleID,
        category: "Plugin"
    )
}
