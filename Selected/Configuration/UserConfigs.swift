//
//  UserConfigs.swift
//  Selected
//
//  Created by sake on 2024/3/17.
//

import Foundation

typealias ActionID = String

// AppCondition 指定某个 app 下的 action 列表。
struct AppCondition: Codable {
    let bundleID: String    // bundleID of app
    var actions: [ActionID] // 在这个 app 下启用的插件列表，以及显示顺序
}

// URLCondition 指定某个 url 下的 action 列表。
struct URLCondition: Codable {
    let url: String         // URLCondition
    var actions: [ActionID] // 在这个 app 下启用的插件列表，以及显示顺序
}

struct UserConfiguration: Codable {
    var defaultActions: [ActionID]
    var appConditions: [AppCondition] // 用户设置的应用列表
    var urlConditions: [URLCondition] // 用户设置的 URL 列表


    func appCondition(bundleID: String) -> AppCondition? {
        if let condition = appConditions.first(where: { $0.bundleID == bundleID }) {
            return condition
        }
        return defaultActions.isEmpty ? nil : AppCondition(bundleID: bundleID, actions: defaultActions)
    }

    func urlCondition(url: String) -> URLCondition? {
        urlConditions.first { url.contains($0.url) }
    }
}
