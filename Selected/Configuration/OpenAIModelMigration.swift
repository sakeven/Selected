import Foundation

enum OpenAIModelMigration {
    private static let removedModels = [
        "gpt-5.2", "gpt-5.2-pro", "gpt-5.1", "gpt-5-mini", "gpt-5", "gpt-5-pro",
        "gpt-5-nano", "gpt-5.4-nano", "gpt-5.3-codex", "gpt-5.2-codex",
        "gpt-5.1-codex", "gpt-5.1-codex-max", "gpt-5.1-codex-mini", "gpt-5-codex",
        "gpt-5-chat-latest", "gpt-5.1-chat-latest", "gpt-5.2-chat-latest", "gpt-5.3-chat-latest",
        "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o", "gpt-4o-mini",
        "gpt-4", "gpt-4-0613", "gpt-4-1106-preview", "gpt-4-turbo", "gpt-4-turbo-preview",
        "gpt-3.5-turbo", "gpt-3.5-turbo-0125", "gpt-3.5-turbo-1106",
        "o4-mini", "o3", "o3-pro", "o3-mini", "o1", "o1-pro", "o1-mini", "o1-preview",
        "o3-deep-research", "o4-mini-deep-research"
    ]

    static func chatReplacement(for model: String) -> String? {
        guard matches(model, in: removedModels) else { return nil }
        let smallerModels = ["gpt-5-mini", "gpt-5-nano", "gpt-5.4-nano", "gpt-5.1-codex-mini",
                             "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o", "gpt-4o-mini",
                             "o4-mini", "o3-mini", "o1-mini", "gpt-3.5-turbo", "gpt-3.5-turbo-0125", "gpt-3.5-turbo-1106"]
        return matches(model, in: smallerModels) ? .gpt6_luna : .gpt6_1_sol
    }

    static func translationReplacement(for model: String) -> String? {
        matches(model, in: removedModels) ? .gpt6_luna : nil
    }

    static func speechReplacement(for model: String) -> String? {
        matches(model, in: ["tts-1", "tts-1-hd", "gpt-4o-mini-tts", "gpt-realtime-2.1-mini"]) ? .gpt_audio_1_5 : nil
    }

    private static func matches(_ model: String, in models: [String]) -> Bool {
        let base = model.replacingOccurrences(of: #"-\d{4}-\d{2}-\d{2}$"#, with: "", options: .regularExpression)
        return models.contains(model) || models.contains(base)
    }
}
