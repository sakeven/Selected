import Testing
@testable import Selected

struct ModelMigrationTests {
    @Test(arguments: ["gpt-5-mini", "gpt-4.1-mini", "o4-mini", "gpt-4o-mini", "o3-mini"])
    func smallLegacyModelsKeepTerraMigration(model: String) {
        #expect(OpenAIModelMigration.chatReplacement(for: model) == "gpt-5.6-terra")
        #expect(OpenAIModelMigration.translationReplacement(for: model) == "gpt-5.6-luna")
    }

    @Test(arguments: ["gpt-5.2", "gpt-5.2-pro", "gpt-5.1", "gpt-5", "gpt-5-pro", "gpt-4.1", "o3", "gpt-4o"])
    func otherLegacyModelsKeepSolMigration(model: String) {
        #expect(OpenAIModelMigration.chatReplacement(for: model) == "gpt-5.6-sol")
        #expect(OpenAIModelMigration.translationReplacement(for: model) == "gpt-5.6-luna")
    }

    @Test(arguments: ["gpt-6-astra", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna", "gpt-5.6", "custom-model", ""])
    func currentAndCustomModelsDoNotRewritePreferences(model: String) {
        #expect(OpenAIModelMigration.chatReplacement(for: model) == nil)
        #expect(OpenAIModelMigration.translationReplacement(for: model) == nil)
    }
}
