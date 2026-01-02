//
//  JSONFormat.swift
//  Selected
//
//  Created by sake on 2/1/26.
//


import Testing
@testable import Selected

struct JSONFormatTests {

    @Test func isValidJSON() throws {
        try #require(JSONFormatter.isValidJSON("{}"))
        try #require(JSONFormatter.isValidJSON("[]"))
        try #require(JSONFormatter.isValidJSON("{\"a\": \"b\"}"))
        try #require(!JSONFormatter.isValidJSON("["))
        try #require(!JSONFormatter.isValidJSON("}"))
        try #require(!JSONFormatter.isValidJSON("{\"a\": b\"}"))
    }

    @Test func prettify() throws {
        try #require(JSONFormatter.prettify("{}") == "{\n\n}")
        try #require(JSONFormatter.prettify("{\"a\":\"b\"}") == """
{
  "a" : "b"
}
""")
    }
}
