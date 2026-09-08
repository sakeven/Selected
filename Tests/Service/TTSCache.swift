import Foundation
import Testing
@testable import Selected

struct TTSCacheTests {
    @Test func cacheExpiresAfter120SecondsWithoutExtendingOnRead() {
        var cache = TTSCache()
        let start = Date(timeIntervalSince1970: 1000)
        let audio = Data([1, 2, 3])
        cache.store(audio, for: "Hello", at: start)
        #expect(cache.data(for: "Hello", at: start.addingTimeInterval(60)) == audio)
        #expect(cache.data(for: "Hello", at: start.addingTimeInterval(120)) == audio)
        #expect(cache.data(for: "Hello", at: start.addingTimeInterval(120.001)) == nil)
    }

    @Test func distinctTextHasIndependentAudioAndExpiry() {
        var cache = TTSCache()
        let start = Date(timeIntervalSince1970: 1000)
        cache.store(Data([1]), for: "Hello", at: start)
        cache.store(Data([2]), for: "世界", at: start.addingTimeInterval(100))
        #expect(cache.data(for: "Hello", at: start.addingTimeInterval(121)) == nil)
        #expect(cache.data(for: "世界", at: start.addingTimeInterval(121)) == Data([2]))
        #expect(cache.data(for: "Missing", at: start.addingTimeInterval(121)) == nil)
        cache.store(Data([3]), for: "世界", at: start.addingTimeInterval(121))
        #expect(cache.data(for: "世界", at: start.addingTimeInterval(230)) == Data([3]))
    }
}
