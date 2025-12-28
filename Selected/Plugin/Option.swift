//
//  Option.swift
//  Selected
//
//  Created by sake on 2024/3/30.
//

import Foundation

// it stores at ~/Library/Preferences/io.kitool.Selected.<plugin-name>.plist
struct Option: Decodable {
    var identifier: String
    var type: OptionType
    var description: String?
    var defaultVal: String?
    var values: [String]?
}

enum OptionType: String, Decodable {
    case string, boolean, multiple, secret
}

func getBoolOption(pluginName: String, identifier: String) -> Bool {
    guard let defaults = UserDefaults(suiteName: defaultsSuiteName(pluginName)) else {
        return false
    }
    return defaults.bool(forKey: identifier)
}

func getStringOption(pluginName: String, identifier: String) -> String? {
    let defaults = UserDefaults(suiteName: defaultsSuiteName(pluginName))
    return defaults?.string(forKey: identifier)
}

func setOption(pluginName: String, identifier: String, val: Any) {
    guard let defaults = UserDefaults(suiteName: defaultsSuiteName(pluginName)) else {
        return
    }
    defaults.set(val, forKey: identifier)
    PluginManager.shared.optionValueChangeCnt += 1
}

func removeOptionsOf(pluginName: String) {
    UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName(pluginName))
}

func defaultsSuiteName(_ pluginName: String) -> String {
    return SelfBundleID + "." + pluginName
}
