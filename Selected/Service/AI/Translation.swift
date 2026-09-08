import Defaults
import Foundation

func isWord(str: String) -> Bool {
    str.allSatisfy { $0.isLetter || $0 == "-" }
}

struct Translation {
    let toLanguage: String

    func translate(content: String, completion: @escaping (_: String) -> Void) async -> Void {
        if toLanguage == "cn" {
            await contentTrans2Chinese(content: content, completion: completion)
        } else if toLanguage == "en" {
            await contentTrans2English(content: content, completion: completion)
        }
    }

    private func contentTrans2Chinese(content: String, completion: @escaping (_: String) -> Void) async -> Void{
        var prompt = "你是一位精通简体中文的专业翻译。翻译指定的内容到中文。规则：请直接回复翻译后的内容。内容为：{selected.text}"
        if isWord(str: content) {
            prompt = "翻译以下单词到中文，详细说明单词的不同意思，并且给出原语言的例句与翻译。使用 markdown 的格式回复，要求第一行标题为单词。单词为：{selected.text}"
        }
        guard let translator = TranslateService(prompt: prompt) else {
            completion("no model \(Defaults[.aiService])")
            return
        }
        do {
            let stream = translator.chatOnce(selectedText: content)
            for try await event in stream {
                if case let .textDelta(txt) = event{
                    completion(txt)
                }
            }
        } catch {
            logger.error("contentTrans2Chinese error \(error)")
        }
    }


    private func contentTrans2English(content: String, completion: @escaping (_: String) -> Void)  async -> Void{
        let prompt = "You are a professional translator proficient in English. Translate the following content into English. Rule: reply with the translated content directly. The content is：{selected.text}"
        guard let translator = TranslateService(prompt: prompt) else {
            completion("no model \(Defaults[.aiService])")
            return
        }
        do {
            let stream = translator.chatOnce(selectedText: content)
            for try await event in stream {
                if case let .textDelta(txt) = event{
                    completion(txt)
                }
            }
        } catch {
            logger.error("catch \(error)")
        }
    }


    struct TranslateService{
        var chatService: AIProvider

        init?(prompt: String){
            switch Defaults[.aiService] {
                case "OpenAI":
                    chatService = OpenAIProvider(prompt: prompt, model: Defaults[.openAITranslationModel], reasoning: false)
                case "Claude":
                    chatService = ClaudeAIProvider(prompt: prompt, model: .claude_haiku_4_5)
                default:
                    return nil
            }
        }

        func chatOnce(selectedText: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
            chatService.chatOnce(selectedText: selectedText)
        }
    }
}
