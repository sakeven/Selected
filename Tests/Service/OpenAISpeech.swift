import AVFoundation
import Defaults
import Foundation
import OpenAI
import Testing
@testable import Selected

@Suite(.serialized)
struct OpenAISpeechTests {
    @Test func speechQueryPreservesTextAndDelivery() throws {
        let speech = OpenAISpeech(host: "", model: "gpt-audio-1.5", voice: .coral, instructions: "Speak slowly.")
        let text = "你好，世界。\nQuote: \"Hello\"."
        let query = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(speech.query(text: text))) as? [String: Any])
        #expect(query["model"] as? String == "gpt-audio-1.5")
        #expect(query["modalities"] as? [String] == ["text", "audio"])
        #expect(query["stream"] as? Bool == false)
        #expect(query["store"] as? Bool == false)
        let audio = try #require(query["audio"] as? [String: Any])
        #expect(audio["voice"] as? String == "coral")
        #expect(audio["format"] as? String == "wav")
        let messages = try #require(query["messages"] as? [[String: Any]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] as? String == "system")
        #expect((messages[0]["content"] as? String)?.contains("exactly as written") == true)
        #expect((messages[0]["content"] as? String)?.contains("Speak slowly.") == true)
        #expect(messages[1]["role"] as? String == "user")
        #expect(messages[1]["content"] as? String == text)
        #expect(query["tools"] == nil)
    }

    @Test(arguments: ["", "api.openai.com", "speech.example.com"])
    func usesHTTPSAndDecodesPlayableAudio(host: String) async throws {
        let wav = try #require(Data(base64Encoded: "UklGRqS7AABXQVZFZm10IBAAAAABAAEAwF0AAIC7AAACABAAZGF0YYC7AAA=")) + Data(repeating: 0, count: 48_000)
        let response = try completion(audio: wav.base64EncodedString())
        let session = makeSession { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.scheme == "https")
            #expect(request.url?.host == (host.isEmpty ? "api.openai.com" : host))
            #expect(request.url?.path == "/v1/chat/completions")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            return (200, response)
        }
        defer { session.invalidateAndCancel() }
        let speech = OpenAISpeech(host: host, model: "gpt-audio-1.5", voice: .shimmer, instructions: "")
        let audio = try await speech.audio(for: "Hello", token: "test-key", session: session)
        #expect(audio == wav)
        let player = try AVAudioPlayer(data: audio)
        #expect(player.numberOfChannels == 1)
        #expect(abs(player.duration - 1) < 0.001)
        #expect(player.format.sampleRate == 24_000)
    }

    @Test(arguments: ["length", "content_filter", "tool_calls"])
    func incompleteResponsesDoNotReturnPartialAudio(finishReason: String) async throws {
        let response = try completion(audio: "AAAA", finishReason: finishReason)
        let session = makeSession { _ in (200, response) }
        defer { session.invalidateAndCancel() }
        let speech = OpenAISpeech(host: "", model: "gpt-audio-1.5", voice: .shimmer, instructions: "")
        await #expect(throws: (any Error).self) {
            try await speech.audio(for: "Hello", token: "test-key", session: session)
        }
    }

    @Test(arguments: [nil, "", "%%%"] as [String?])
    func rejectsMissingOrInvalidAudio(encodedAudio: String?) async throws {
        let response = try completion(audio: encodedAudio)
        let session = makeSession { _ in (200, response) }
        defer { session.invalidateAndCancel() }
        let speech = OpenAISpeech(host: "", model: "gpt-audio-1.5", voice: .shimmer, instructions: "")
        await #expect(throws: URLError(.cannotDecodeContentData)) {
            try await speech.audio(for: "Hello", token: "test-key", session: session)
        }
    }

    @Test func refusalsAreReportedInsteadOfPlayingAudio() async throws {
        let response = try completion(audio: "AAAA", refusal: "Cannot read this text")
        let session = makeSession { _ in (200, response) }
        defer { session.invalidateAndCancel() }
        let speech = OpenAISpeech(host: "", model: "gpt-audio-1.5", voice: .shimmer, instructions: "")
        do {
            _ = try await speech.audio(for: "Hello", token: "test-key", session: session)
            Issue.record("Expected the refusal")
        } catch {
            #expect(error.localizedDescription == "Cannot read this text")
        }
    }

    @Test func serviceErrorsArePreserved() async {
        let session = makeSession { _ in
            (401, Data(#"{"error":{"message":"Access denied","type":"invalid_request_error","code":"invalid_api_key"}}"#.utf8))
        }
        defer { session.invalidateAndCancel() }
        let speech = OpenAISpeech(host: "", model: "gpt-audio-1.5", voice: .shimmer, instructions: "")
        do {
            _ = try await speech.audio(for: "Hello", token: "test-key", session: session)
            Issue.record("Expected the server error")
        } catch {
            #expect(error.localizedDescription.contains("Access denied"))
        }
    }

    @Test func cancellingStopsTheHTTPRequest() async {
        let (started, continuation) = AsyncStream<Void>.makeStream()
        let session = makeSession { _ in
            continuation.yield(())
            return nil
        }
        defer {
            continuation.finish()
            session.invalidateAndCancel()
        }
        let speech = OpenAISpeech(host: "", model: "gpt-audio-1.5", voice: .shimmer, instructions: "")
        let task = Task { try await speech.audio(for: "Hello", token: "test-key", session: session) }
        for await _ in started { break }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected the request to be cancelled")
        } catch {
            #expect((error as? URLError)?.code == .cancelled)
        }
    }

    @Test(arguments: ChatQuery.AudioOptions.AudioOptionsSpeechVoice.allCases)
    func restoresExistingVoicePreferences(voice: ChatQuery.AudioOptions.AudioOptionsSpeechVoice) throws {
        let name = "SelectedTests.Speech.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let key = Defaults.Key<ChatQuery.AudioOptions.AudioOptionsSpeechVoice>("voice", default: .shimmer, suite: defaults)
        defaults.set(String(decoding: try JSONEncoder().encode(voice.rawValue), as: UTF8.self), forKey: "voice")
        #expect(Defaults[key] == voice)
    }

    private func makeSession(handler: @escaping (URLRequest) throws -> (Int, Data)?) -> URLSession {
        SpeechURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SpeechURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func completion(audio: String?, finishReason: String = "stop", refusal: String? = nil) throws -> Data {
        var message: [String: Any] = ["role": "assistant"]
        if let audio {
            message["audio"] = ["data": audio, "id": "audio-test", "expires_at": 2_000_000_000, "transcript": "Hello"]
        }
        if let refusal { message["refusal"] = refusal }
        return try JSONSerialization.data(withJSONObject: [
            "id": "chatcmpl-test", "object": "chat.completion", "created": 1_000_000_000, "model": "gpt-audio-1.5",
            "choices": [["index": 0, "finish_reason": finishReason, "message": message]]
        ])
    }
}

private final class SpeechURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data)?)!

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let (status, data) = try Self.handler(request) else { return }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
