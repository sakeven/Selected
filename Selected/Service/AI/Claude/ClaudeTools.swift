import Foundation
import SwiftAnthropic

struct ClaudeToolUse {
    let id: String
    let name: String
    var input: String
}

// MARK: - 工具管理模块

enum ClaudeTools {

    /// 根据 FunctionDefinition 列表生成工具描述
    static func generateTools(from functions: [FunctionDefinition]?) -> [MessageParameter.Tool] {
        guard let functions = functions else { return [] }
        var tools = [MessageParameter.Tool]()
        for fc in functions {
            guard let schema = try? JSONDecoder().decode(JSONSchema.self, from: fc.parameters.data(using: .utf8)!) else {
                continue
            }
            let tool = MessageParameter.Tool.function(name: fc.name, description: fc.description, inputSchema: schema)
            tools.append(tool)
        }
        return tools
    }

    /// 根据工具使用列表调用相应的工具函数，并返回工具调用结果消息
    static func callTools(
        toolUseList: [ClaudeToolUse],
        with functionDefinitions: [FunctionDefinition],
        options: [String: String],
        continuation: AsyncThrowingStream<AIStreamEvent, Error>.Continuation,
    ) async throws -> [MessageParameter.Message] {
        var fcSet = [String: FunctionDefinition]()
        for fc in functionDefinitions {
            fcSet[fc.name] = fc
        }
        var toolUseResults = [MessageParameter.Message.Content.ContentObject]()

        for tool in toolUseList {

            if tool.name == "display_svg" {
                continuation.yield(.toolCallStarted(.init(
                    id: tool.id,
                    name: tool.name,
                    message: NSLocalizedString("calling_tool", comment: "tool message"),
                    arguments: tool.input,
                    command: nil,
                    workdir: nil,
                    sourceLinks: []
                )))
                // 打开 SVG 浏览器预览
                _ = openSVGInBrowser(svgData: tool.input)
                let msg = String(format: NSLocalizedString("display_svg", comment: ""))
                continuation.yield(.toolCallFinished(.init(
                    id: tool.id,
                    name: tool.name,
                    ret: msg,
                    arguments: tool.input,
                    command: nil,
                    workdir: nil,
                    sourceLinks: []
                )))
                toolUseResults.append(.toolResult(tool.id, "display svg successfully"))
                continue
            }

            guard let fc = fcSet[tool.name] else { continue }

            var message = String(format: NSLocalizedString("calling_tool", comment: "tool message"), tool.name)
            if let template = fc.template {
                message = renderTemplate(templateString: template, json: tool.input)
            }
            continuation.yield(.toolCallStarted(.init(
                id: tool.id,
                name: tool.name,
                message: message,
                arguments: tool.input,
                command: fc.commandLine,
                workdir: fc.workdir,
                sourceLinks: []
            )))

            if let ret = try fc.Run(arguments: tool.input, options: options) {
                let statusMessage = (fc.showResult ?? true)
                ? ret
                : String(format: NSLocalizedString("called_tool", comment: "tool message"), fc.name)
                continuation.yield(.toolCallFinished(.init(
                    id: tool.id,
                    name: tool.name,
                    ret: statusMessage,
                    arguments: tool.input,
                    command: fc.commandLine,
                    workdir: fc.workdir,
                    sourceLinks: []
                )))
                toolUseResults.append(.toolResult(tool.id, ret))
            }
        }
        return [.init(role: .user, content: .list(toolUseResults))]
    }
}
