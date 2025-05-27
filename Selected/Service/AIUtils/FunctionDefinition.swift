//
//  FunctionDefinition.swift
//  Selected
//
//  Created by sake on 20/3/25.
//


import Foundation
import OpenAI

public struct FunctionDefinition: Codable, Equatable {
    /// 函数名称，必须只包含 a-z, A-Z, 0-9，下划线或连字符，最大长度 64。
    public let name: String
    /// 函数的描述信息
    public let description: String
    /// 函数参数的 JSON Schema 描述
    public let parameters: String
    /// 执行该函数时所需的命令数组
    public var command: [String]?
    /// 命令执行时的工作目录
    public var workdir: String?
    /// 是否显示执行结果，默认为 true
    public var showResult: Bool? = true
    /// 可选的模板字符串
    public var template: String?

    /// 运行该函数对应的命令
    func Run(arguments: String, options: [String: String] = [:]) throws -> String? {
        guard let command = self.command else {
            return nil
        }
        // 获取除第一个元素外的参数
        var args = Array(command.dropFirst())
        args.append(arguments)

        // 设置环境变量
        var env = [String: String]()
        options.forEach { key, value in
            env["SELECTED_OPTIONS_\(key.uppercased())"] = value
        }
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:" + path
        }
        // 注意：这里假定 executeCommand(workdir:command:arguments:withEnv:) 已经在其他地方实现
        return try executeCommand(workdir: workdir!, command: command[0], arguments: args, withEnv: env)
    }

    /// 解析 JSON Schema 参数为 FunctionParameters 对象
    func getParameters() -> AnyJSONSchema? {
        return try? JSONDecoder().decode(AnyJSONSchema.self, from: parameters.data(using: .utf8)!)
    }
}
