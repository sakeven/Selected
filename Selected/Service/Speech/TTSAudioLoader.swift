import Foundation

@MainActor
final class TTSAudioLoader {
    private var cache = TTSCache()

    func data(for text: String, fetch: () async throws -> Data) async throws -> Data {
        if let cached = cache.data(for: text, at: Date()) {
            logger.info("Using cached TTS data")
            return cached
        }
        let data = try await fetch()
        cache.store(data, for: text, at: Date())
        return data
    }
}
