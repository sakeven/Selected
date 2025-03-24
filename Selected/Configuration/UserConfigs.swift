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
}

// ConfigurationManager 读取、保存应用的复杂配置，比如什么应用下启用哪些 action 等等。
// 配置保存在 "Library/Application Support/Selected" 下。
class ConfigurationManager {
    static let shared = ConfigurationManager()
    private let configurationFileName = "UserConfiguration.json"
    
    var userConfiguration: UserConfiguration
    
    init() {
        userConfiguration = UserConfiguration(defaultActions: [], appConditions: [], urlConditions: [])
        loadConfiguration()
    }
    
    func getAppCondition(bundleID: String) -> AppCondition? {
        for condition in userConfiguration.appConditions {
            if condition.bundleID == bundleID {
                return condition
            }
        }
        if userConfiguration.defaultActions.count > 0 {
            return AppCondition(bundleID: bundleID, actions: userConfiguration.defaultActions)
        }
        return nil
    }
    
    func getURLCondition(url: String) -> URLCondition? {
        for condition in userConfiguration.urlConditions {
            if url.contains(condition.url) {
                return condition
            }
        }
        return nil
    }
    
    func loadConfiguration() {
        let fileURL = appSupportURL.appendingPathComponent(configurationFileName)
        print("UserConfiguration \(fileURL.absoluteString)")
        do {
            let data = try Data(contentsOf: fileURL)
            userConfiguration = try JSONDecoder().decode(UserConfiguration.self, from: data)
        } catch {
            print("Error loading configuration: \(error)")
        }
    }
    
    func saveConfiguration() {
        let fileURL = appSupportURL.appendingPathComponent(configurationFileName)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(userConfiguration)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Error saving configuration: \(error)")
        }
    }
}
