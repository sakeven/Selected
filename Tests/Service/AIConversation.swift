import Foundation
import Testing
@testable import Selected

struct AIConversationTests {
    @Test func stopsAfterAnswerAndEmitsDoneOnce() async throws {
        var rounds = 0
        let stream = conversationStream(maxToolLoops: 8) { continuation in
            rounds += 1
            continuation.yield(.textDelta("round \(rounds)"))
            return rounds < 3
        }
        var text: [String] = []
        var done = 0
        for try await event in stream {
            if case .textDelta(let value) = event { text.append(value) }
            if case .done = event { done += 1 }
        }
        #expect(rounds == 3)
        #expect(text == ["round 1", "round 2", "round 3"])
        #expect(done == 1)
    }

    @Test func toolLoopLimitRemainsEightAndEndsWithErrorEvent() async throws {
        var rounds = 0
        let stream = conversationStream(maxToolLoops: 8) { _ in
            rounds += 1
            return true
        }
        var errors: [String] = []
        var done = false
        for try await event in stream {
            if case .error(let message) = event { errors.append(message) }
            if case .done = event { done = true }
        }
        #expect(rounds == 8)
        #expect(errors == ["tooManyToolLoops"])
        #expect(!done)
    }

    @Test func thrownRoundErrorIsPropagatedWithoutDoneEvent() async {
        let stream = conversationStream(maxToolLoops: 8) { _ in throw ConversationTestError.failed }
        do {
            for try await _ in stream { Issue.record("Unexpected event after a failed round") }
            Issue.record("Expected round failure")
        } catch {
            #expect(error as? ConversationTestError == .failed)
        }
    }

    @Test func cancellingConsumerCancelsTheRunningRound() async throws {
        let started = AsyncStream<Void>.makeStream()
        let cancelled = AsyncStream<Bool>.makeStream()
        let stream = conversationStream(maxToolLoops: 8) { _ in
            started.continuation.yield(())
            started.continuation.finish()
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                cancelled.continuation.yield(Task.isCancelled)
                cancelled.continuation.finish()
                throw error
            }
            cancelled.continuation.yield(false)
            cancelled.continuation.finish()
            return false
        }
        let consumer = Task { for try await _ in stream {} }
        for await _ in started.stream { break }
        consumer.cancel()
        _ = await consumer.result
        for await wasCancelled in cancelled.stream { #expect(wasCancelled) }
    }
}

private enum ConversationTestError: Error {
    case failed
}
