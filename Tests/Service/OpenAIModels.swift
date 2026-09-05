import Foundation
import OpenAI
import Testing
@testable import Selected

struct OpenAIModelsTests {
    @Test(arguments: ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna", "gpt-6-astra"])
    func currentModelsAreSelectable(model: String) {
        #expect(OpenAIModels.contains(model))
        #expect(OpenAITranslationModels.contains(model))
        #expect(isReasoningModel(model))
    }

    @Test(arguments: ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna", "gpt-5.6"])
    func translationExplicitlyDisablesReasoning(model: String) throws {
        let reasoning = try #require(model.reasoningConfiguration(preferred: .xhigh, thinking: false))
        let query = CreateModelResponseQuery(input: .textInput("Translate hello"), model: model, reasoning: reasoning)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(query)) as? [String: Any])
        let encodedReasoning = try #require(json["reasoning"] as? [String: Any])
        #expect(encodedReasoning["effort"] as? String == "none")
        #expect(encodedReasoning["summary"] == nil)
    }

    @Test(arguments: [OpenAIModelReasoningEffort.none, .minimal])
    func astraRejectsUnsupportedSavedEfforts(effort: OpenAIModelReasoningEffort) {
        let reasoning = OpenAIModel.gpt6_astra.reasoningConfiguration(preferred: effort, thinking: true)
        #expect(reasoning?.effort == .medium)
        #expect(!OpenAIModel.gpt6_astra.supportedReasoningEfforts.contains(effort))
    }

    @Test func astraUsesLowEffortForQuickActions() {
        #expect(OpenAIModel.gpt6_astra.reasoningConfiguration(preferred: .xhigh, thinking: false)?.effort == .low)
    }

    @Test(arguments: [OpenAIModelReasoningEffort.low, .medium, .high, .xhigh])
    func preservesSupportedEffort(effort: OpenAIModelReasoningEffort) {
        for model in [OpenAIModel.gpt6_astra, .gpt5_6_sol, .gpt5_6_terra, .gpt5_6_luna] {
            #expect(model.reasoningConfiguration(preferred: effort, thinking: true)?.effort == effort)
        }
    }

    @Test(arguments: ["gpt-5.2", "gpt-5.2-pro", "gpt-5.1", "gpt-5", "gpt-5-pro", "gpt-5-mini",
                      "gpt-4.1", "gpt-4.1-mini", "gpt-4o", "gpt-4o-mini", "o4-mini", "o3", "o3-mini"])
    func removedChatModelsAreUnavailable(model: String) {
        #expect(!OpenAIModels.contains(model))
        #expect(!OpenAITranslationModels.contains(model))
        #expect(!isReasoningModel(model))
    }

    @Test func customModelsDoNotInheritOpenAIReasoning() {
        #expect("custom-model".reasoningConfiguration(preferred: .high, thinking: true) == nil)
    }
}
