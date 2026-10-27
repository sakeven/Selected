import Foundation

struct ChatService: AIProvider{
    var chatService: AIProvider

    init(prompt: String, tools: [FunctionDefinition]? = nil, options: [String:String], reasoning: Bool = true){
        chatService = OpenAIProvider(prompt: prompt, tools: tools, options: options, reasoning: reasoning)
    }


    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        chatService.chat(ctx: ctx)
    }

    func chatFollow(userMessage: UserMessage) -> AsyncThrowingStream<AIStreamEvent, any Error> {
        chatService.chatFollow(userMessage: userMessage)
    }

    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        chatService.chatOnce(selectedText: selectedText)
    }
}
