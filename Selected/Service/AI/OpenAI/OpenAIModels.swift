import OpenAI

typealias OpenAIModel = Model

extension Model {
    static let gpt6_astra = "gpt-6-astra"
    static let gpt5_6_sol = "gpt-5.6-sol"
    static let gpt5_6_terra = "gpt-5.6-terra"
    static let gpt5_6_luna = "gpt-5.6-luna"
}

let OpenAIModels: [Model] = [.gpt6_astra, .gpt5_6_sol, .gpt5_6_terra, .gpt5_6_luna]
let OpenAITTSModels: [Model] = [.gpt_4o_mini_tts, .tts_1, .tts_1_hd]
let OpenAITranslationModels: [Model] = [
    .gpt5_6_luna, .gpt5_6_terra, .gpt5_6_sol, .gpt6_astra
]

typealias OpenAIModelReasoningEffort = Components.Schemas.ReasoningEffort
let OpenAIReasoningEfforts = Components.Schemas.ReasoningEffort.allCases

func isReasoningModel(_ model: Model) -> Bool {
    OpenAIModels.contains(model) || model == "gpt-5.6"
}


extension OpenAIModel {
    var supportedReasoningEfforts: [OpenAIModelReasoningEffort] {
        switch self {
        case .gpt6_astra:
            return [.low, .medium, .high, .xhigh]
        case .gpt5_6_sol, .gpt5_6_terra, .gpt5_6_luna, "gpt-5.6":
            return [.none, .low, .medium, .high, .xhigh]
        default:
            return []
        }
    }

    var supportsReasoningEffort: Bool {
        !supportedReasoningEfforts.isEmpty
    }

    func reasoningConfiguration(preferred: OpenAIModelReasoningEffort, thinking: Bool) -> Components.Schemas.Reasoning? {
        let supported = supportedReasoningEfforts
        guard let minimumEffort = supported.first else { return nil }

        let effort: OpenAIModelReasoningEffort
        if !thinking {
            effort = minimumEffort
        } else if supported.contains(preferred) {
            effort = preferred
        } else {
            effort = .medium
        }

        return .init(effort: effort, summary: effort == .none ? nil : .auto)
    }
}
