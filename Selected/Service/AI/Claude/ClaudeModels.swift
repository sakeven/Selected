import Foundation

extension ClaudeModel: @retroactive CaseIterable {
    public static var allCases: [ClaudeModel] {
        [.claude_sonnet_4_5, .claude_haiku_4_5, .claude_opus_4_5, .claude_opus_4_1]
    }
}

public typealias ClaudeModel = String

public extension ClaudeModel {
    static let claude_sonnet_4_5 = "claude-sonnet-4-5"
    static let claude_haiku_4_5 = "claude-haiku-4-5"
    static let claude_opus_4_5 = "claude-opus-4-5"
    static let claude_opus_4_1 = "claude-opus-4-1"
}
