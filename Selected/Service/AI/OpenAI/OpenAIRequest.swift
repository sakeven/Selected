import OpenAI

extension CreateModelResponseQuery {
    func continuing(with input: Input, previousResponseID: String?) -> CreateModelResponseQuery {
        CreateModelResponseQuery(
            input: input,
            model: model,
            instructions: instructions,
            previousResponseId: previousResponseID,
            reasoning: reasoning,
            stream: true,
            tools: tools
        )
    }
}
