import Foundation

enum OpenAIModelMigration {
    private static let removedModels = [
        "gpt-5.2", "gpt-5.2-pro", "gpt-5.1", "gpt-5-mini", "gpt-5", "gpt-5-pro",
        "gpt-4.1", "gpt-4.1-mini", "o4-mini", "o3", "gpt-4o", "gpt-4o-mini", "o3-mini"
    ]

    static func chatReplacement(for model: String) -> String? {
        guard removedModels.contains(model) else { return nil }
        let smallerModels = ["gpt-5-mini", "gpt-4.1-mini", "o4-mini", "gpt-4o-mini", "o3-mini"]
        return smallerModels.contains(model) ? .gpt5_6_terra : .gpt5_6_sol
    }

    static func translationReplacement(for model: String) -> String? {
        removedModels.contains(model) ? .gpt5_6_luna : nil
    }
}
