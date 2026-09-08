import Foundation

func conversationStream(
    maxToolLoops: Int,
    round: @escaping (AsyncThrowingStream<AIStreamEvent, Error>.Continuation) async throws -> Bool
) -> AsyncThrowingStream<AIStreamEvent, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                for _ in 0..<maxToolLoops {
                    try Task.checkCancellation()
                    let hasToolCall = try await round(continuation)
                    if !hasToolCall {
                        continuation.yield(.done)
                        continuation.finish()
                        return
                    }
                }
                continuation.yield(.error("tooManyToolLoops"))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
