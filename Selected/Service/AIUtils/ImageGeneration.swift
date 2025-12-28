//
//  ImageGeneration.swift
//  Selected
//
//  Created by sake on 20/3/25.
//


import Foundation
import OpenAI

public struct ImageGeneration {
    /// 根据传入参数调用 Dall-E 3 生成图片，并返回图片 URL
    public static func generateDalle3Image(openAI: OpenAI, arguments: String) async throws -> String {
        let promptData = try JSONDecoder().decode(Dalle3Prompt.self, from: arguments.data(using: .utf8)!)
        let imageQuery = ImagesQuery(prompt: promptData.prompt, model: .dall_e_3)
        let res = try await openAI.images(query: imageQuery)
        guard let url = res.data.first?.url else {
            throw NSError(domain: "ImageGeneration", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image URL returned"])
        }
        AppLogger.ai.debug("image URL: \(url)")
        return url
    }
}

public struct Dalle3Prompt: Codable, Equatable {
    /// 用于图片生成的提示语
    public let prompt: String
}
