//
//  PluginInfo.swift
//  Selected
//
//  Created by sake on 11/1/26.
//

import Testing
import Yams
@testable import Selected

struct PluginInfoTests {

    @Test func decodePlugin() throws {
        let decoder = YAMLDecoder()
        let content = """
info:
  icon: file://./go-logo-white.svg
  name: Go Search
actions:
  - meta:
      title: GoSearch
      icon: file://./go-logo-blue.svg
      identifier: selected.gosearch
    url:
      url: https://pkg.go.dev/search?limit=25&m=symbol&q={text}
"""
        let plugin: Plugin = try! decoder.decode(Plugin.self, from: content)
        try #require(plugin.info.name == "Go Search")
        try #require(plugin.actions[0].meta.title == "GoSearch")
        try #require(plugin.actions[0].url?.url == "https://pkg.go.dev/search?limit=25&m=symbol&q={text}")

    }
}
