import Testing
@testable import Selected

struct ModelMigrationTests {
    @Test(arguments: ["gpt-5-mini", "gpt-5-nano", "gpt-5.4-nano", "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano",
                      "gpt-4o", "gpt-4o-mini", "o4-mini", "o3-mini", "gpt-4o-2024-11-20", "gpt-5-mini-2025-08-07"])
    func fastLegacyModelsMigrateToLuna(model: String) {
        #expect(OpenAIModelMigration.chatReplacement(for: model) == "gpt-6-luna")
        #expect(OpenAIModelMigration.translationReplacement(for: model) == "gpt-6-luna")
    }

    @Test(arguments: ["gpt-5.2", "gpt-5.2-pro", "gpt-5.1", "gpt-5", "gpt-5-pro", "o3", "o3-pro", "gpt-5.3-codex",
                      "gpt-5.1-2025-11-13", "gpt-5-2025-08-07", "o3-2025-04-16", "gpt-4-0613"])
    func reasoningLegacyModelsMigrateToCurrentSol(model: String) {
        #expect(OpenAIModelMigration.chatReplacement(for: model) == "gpt-6.1-sol")
        #expect(OpenAIModelMigration.translationReplacement(for: model) == "gpt-6-luna")
    }

    @Test(arguments: ["gpt-6.1-sol", "gpt-6-sol", "gpt-6-luna", "gpt-6-astra", "gpt-5.6-sol", "gpt-5.6-terra",
                      "gpt-5.6-luna", "gpt-5.6", "custom-model", "gpt-4o-custom", "gpt-4o-2026-custom", ""])
    func currentAndCustomModelsDoNotRewritePreferences(model: String) {
        #expect(OpenAIModelMigration.chatReplacement(for: model) == nil)
        #expect(OpenAIModelMigration.translationReplacement(for: model) == nil)
    }

    @Test(arguments: ["tts-1", "tts-1-hd", "gpt-4o-mini-tts", "gpt-4o-mini-tts-2025-03-20", "gpt-4o-mini-tts-2025-12-15", "gpt-realtime-2.1-mini"])
    func previousSpeechModelsMigrateToHTTPAudio(model: String) {
        #expect(OpenAIModelMigration.speechReplacement(for: model) == "gpt-audio-1.5")
    }

    @Test(arguments: ["gpt-audio-1.5", "custom-model", "gpt-4o-mini-tts-custom", ""])
    func currentAndCustomSpeechModelsArePreserved(model: String) {
        #expect(OpenAIModelMigration.speechReplacement(for: model) == nil)
    }
}
