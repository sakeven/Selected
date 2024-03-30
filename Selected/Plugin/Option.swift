//
//  Option.swift
//  Selected
//
//  Created by sake on 2024/3/30.
//

import Foundation


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
