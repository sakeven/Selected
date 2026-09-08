import Foundation

protocol AIProvider {
    func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error>
    func chat(ctx: ChatContext) -> AsyncThrowingStream<AIStreamEvent, Error>
    func chatFollow(userMessage: UserMessage) -> AsyncThrowingStream<AIStreamEvent, Error>
}
