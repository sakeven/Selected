import Foundation
import Testing
@testable import Selected

struct TTSAudioLoaderTests {
    @Test @MainActor func reusesCompletedAudioWithoutFetchingAgain() async throws {
        let loader = TTSAudioLoader()
        let bytes = Data("audio".utf8)
        let first = try await loader.data(for: "text") { bytes }
        let second = try await loader.data(for: "text") {
            Issue.record("Cached audio should not trigger another request")
            return Data()
        }
        #expect(first == bytes)
        #expect(second == bytes)
    }

    @Test @MainActor func failedRequestsCanBeRetried() async throws {
        enum Failure: Error { case unavailable }
        let loader = TTSAudioLoader()
        await #expect(throws: Failure.unavailable) {
            try await loader.data(for: "text") { throw Failure.unavailable }
        }
        let bytes = try await loader.data(for: "text") { Data("retry".utf8) }
        #expect(bytes == Data("retry".utf8))
    }

    @Test @MainActor func concurrentRequestsKeepTheirOwnAudio() async throws {
        let loader = TTSAudioLoader()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<32 {
                group.addTask {
                    let key = "text-\(index)"
                    let bytes = try await loader.data(for: key) {
                        await Task.yield()
                        return Data(key.utf8)
                    }
                    #expect(bytes == Data(key.utf8))
                }
            }
            try await group.waitForAll()
        }
        for index in 0..<32 {
            let key = "text-\(index)"
            let bytes = try await loader.data(for: key) {
                Issue.record("The completed request should remain cached")
                return Data()
            }
            #expect(bytes == Data(key.utf8))
        }
    }
}
