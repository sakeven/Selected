//
//  JSONFormat.swift
//  Selected
//
//  Created by sake on 15/12/25.
//


import Foundation

enum JSONFormatError: Error {
    case invalidJSON
}

struct JSONFormatter {

    static func isValidJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Coarse filtering: If it does not start with { or [, it is directly false.
        guard let first = trimmed.first, first == "{" || first == "[" else {
            return false
        }

        guard let data = trimmed.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// JSON prettify
    static func prettify(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw JSONFormatError.invalidJSON
        }

        let object = try JSONSerialization.jsonObject(with: data, options: [])
        let prettyData = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys,]
        )

        guard let prettyString = String(data: prettyData, encoding: .utf8) else {
            throw JSONFormatError.invalidJSON
        }

        return prettyString
    }
}

