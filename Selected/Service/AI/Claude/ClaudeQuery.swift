import SwiftAnthropic

struct ClaudeQuery {
    private(set) var query: MessageParameter
    private let _tools: [MessageParameter.Tool]

    init(model: Model, systemPrompt: String, tools: [MessageParameter.Tool], reasoning: Bool) {
        var thinking: MessageParameter.Thinking? = nil
        if reasoning {
            thinking = .init(budgetTokens: 2048)
        }
        self.query = MessageParameter(
            model: .other(model.value),
            messages: [],
            maxTokens: 4096,
            system: MessageParameter.System.text(systemPrompt),
            tools: tools,
            thinking: thinking
        )
        self._tools = tools
    }

    mutating func update(with message: MessageParameter.Message) {
        update(with: [message])
    }

    mutating func update(with messages: [MessageParameter.Message]) {
        var _messages = query.messages
        _messages.append(contentsOf: messages)
        query = MessageParameter(
            model: .other(query.model),
            messages: _messages,
            maxTokens: 4096,
            system: query.system,
            tools: self._tools,
            thinking: query.thinking
        )
    }
}
