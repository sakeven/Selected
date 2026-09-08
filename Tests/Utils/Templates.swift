import Foundation
import Testing
@testable import Selected

struct TemplateTests {
    @Test func legacyOptionsKeepReplacementOrderAndUnknownPlaceholders() {
        #expect(replaceOptions(content: "{selected.text}|{selected.options.name}|{unknown}", selectedText: "{selected.options.name}", options: ["name": "世界"]) == "世界|世界|{unknown}")
        #expect(replaceOptions(content: "{selected.text} {selected.options.name}", selectedText: "Hello") == "Hello {selected.options.name}")
    }

    @Test func JSONTemplatesUseDictionaryAndSystemLanguage() {
        #expect(parseJSONString(jsonString: "[]") == nil)
        #expect(parseJSONString(jsonString: "broken") == nil)
        #expect(renderTemplate(templateString: "{{ value }}", json: #"{"value":"世界"}"#) == "世界")
        #expect(renderTemplate(templateString: "{{ system.language }}", json: #"{"system":{"language":"overridden"}}"#) == getCurrentAppLanguage())
        #expect(renderTemplate(templateString: "{{ value }}", json: "not JSON") == "")
        #expect(renderTemplate(templateString: "{% invalid %}", with: [:]) == "")
    }

    @Test func MD5KeepsExistingLowercaseHexEncoding() {
        #expect(MD5(string: "") == "d41d8cd98f00b204e9800998ecf8427e")
        #expect(MD5(string: "hello") == "5d41402abc4b2a76b9719d911017c592")
    }

    @Test func temporaryFileWritesTheOriginalBytesAtRequestedName() throws {
        let name = "selected-bytes-\(UUID()).bin"
        let bytes = Data([0x00, 0xFF, 0x10])
        let url = try #require(createTemporaryURLForData(bytes, fileName: name))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.lastPathComponent == name)
        #expect(try Data(contentsOf: url) == bytes)
    }
}
