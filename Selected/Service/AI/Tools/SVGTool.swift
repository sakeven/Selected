import AppKit
import OpenAI

let svgToolOpenAIDef = ChatQuery.ChatCompletionToolParam.FunctionDefinition(
    name: "svg_dispaly",
    description: "When user requests you to create an SVG, you can use this tool to display the SVG.",
    parameters: .init(
        fields: [
            .type( .object),
            .properties(
                [
                    "raw": .init(
                        fields: [
                            .type(.string), .description("SVG content")
                        ])
                ])
        ])
)



struct SVGData: Codable, Equatable {
    public let raw: String
}

// 输入为 svg 的原始数据，要求保存到一个临时文件里，然后通过默认浏览器打开这个文件。
func openSVGInBrowser(svgData: String) -> Bool {
    do {
        let data = try JSONDecoder().decode(SVGData.self, from: svgData.data(using: .utf8)!)

        // 创建临时文件路径
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("temp_svg_\(UUID().uuidString).svg")

        // 将 SVG 数据写入临时文件
        try data.raw.write(to: tempFile, atomically: true, encoding: .utf8)

        // 使用默认浏览器打开文件
        DispatchQueue.global().async {
            NSWorkspace.shared.open(tempFile)
        }
        return true
    } catch {
        logger.error("open SVG: \(error)")
        return false
    }
}
