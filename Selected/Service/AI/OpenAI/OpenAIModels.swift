import OpenAI

typealias OpenAIModel = Model

extension Model {
    static let gpt6_astra = "gpt-6-astra"
    static let gpt6_1_sol = "gpt-6.1-sol"
    static let gpt6_sol = "gpt-6-sol"
    static let gpt6_luna = "gpt-6-luna"
    static let gpt5_6_sol = "gpt-5.6-sol"
    static let gpt5_6_terra = "gpt-5.6-terra"
    static let gpt5_6_luna = "gpt-5.6-luna"
    static let gpt_audio_1_5 = "gpt-audio-1.5"
}

let OpenAIModels: [Model] = [.gpt6_1_sol, .gpt6_astra, .gpt6_luna, .gpt6_sol, .gpt5_6_sol, .gpt5_6_terra, .gpt5_6_luna]
let OpenAITTSModels: [Model] = [.gpt_audio_1_5]
let OpenAITranslationModels: [Model] = [
    .gpt6_luna, .gpt6_1_sol, .gpt6_astra, .gpt6_sol, .gpt5_6_luna, .gpt5_6_terra, .gpt5_6_sol
]

typealias OpenAIModelReasoningEffort = Components.Schemas.ReasoningEffort
let OpenAIReasoningEfforts = Components.Schemas.ReasoningEffort.allCases

func isReasoningModel(_ model: Model) -> Bool {
    OpenAIModels.contains(model) || model == "gpt-5.6"
}


extension OpenAIModel {
    var supportedReasoningEfforts: [OpenAIModelReasoningEffort] {
        switch self {
        case .gpt6_astra, .gpt6_1_sol:
            return [.low, .medium, .high, .xhigh]
        case .gpt6_sol, .gpt6_luna, .gpt5_6_sol, .gpt5_6_terra, .gpt5_6_luna, "gpt-5.6":
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
