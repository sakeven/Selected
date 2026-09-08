import Foundation

public func executeCommand(
    workdir: String, command: String, arguments: [String] = [], withEnv env: [String: String]) throws -> String? {
    let result = try executeCommandResult(workdir: workdir, command: command, arguments: arguments, withEnv: env)
    guard result.exitCode == 0 else {
        throw NSError(domain: "Selected.Command", code: Int(result.exitCode), userInfo: [
            NSLocalizedDescriptionKey: String(localized: "Command exit code: \(result.exitCode)") + (result.diagnostics.isEmpty ? "" : "\n" + result.diagnostics)
        ])
    }
    return result.output
}

func executeCommandResult(workdir: String, command: String, arguments: [String] = [], withEnv env: [String: String],
                          cancellation: CommandCancellation = CommandCancellation()) throws -> CommandResult {
    let path = "/opt/homebrew/bin:/opt/homebrew/sbin:" + (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
    guard let executable = findExecutablePath(commandName: command, currentDirectoryURL: URL(fileURLWithPath: workdir), path: path) else {
        throw NSError(domain: "Selected.Command", code: 127, userInfo: [NSLocalizedDescriptionKey: String(localized: "Executable not found: \(command)")])
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Selected-Command-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: directory) }
    let stdout = directory.appendingPathComponent("stdout")
    let stderr = directory.appendingPathComponent("stderr")
    FileManager.default.createFile(atPath: stdout.path, contents: nil, attributes: [.posixPermissions: 0o600])
    FileManager.default.createFile(atPath: stderr.path, contents: nil, attributes: [.posixPermissions: 0o600])
    let outputHandle = try FileHandle(forWritingTo: stdout)
    let errorHandle = try FileHandle(forWritingTo: stderr)
    defer { try? outputHandle.close(); try? errorHandle.close() }
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.currentDirectoryURL = URL(fileURLWithPath: workdir)
    process.environment = env.merging(["PATH": path]) { _, new in new }
    process.standardInput = FileHandle.nullDevice
    // Files avoid pipe deadlocks when a command spawns a background child.
    process.standardOutput = outputHandle
    process.standardError = errorHandle
    try cancellation.start(process)
    let timer = DispatchSource.makeTimerSource()
    timer.schedule(deadline: .now() + 60)
    timer.setEventHandler { cancellation.cancel(timedOut: true) }
    timer.activate()
    defer { timer.cancel() }
    process.waitUntilExit()
    try cancellation.check()
    return CommandResult(output: String(decoding: try Data(contentsOf: stdout), as: UTF8.self),
                         diagnostics: String(decoding: try Data(contentsOf: stderr), as: UTF8.self),
                         exitCode: process.terminationStatus)
}


func findExecutablePath(commandName: String, currentDirectoryURL: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first, path: String? = ProcessInfo.processInfo.environment["PATH"]) -> URL? {
    let fileManager = FileManager.default
    // 先检查是否是绝对路径
    let executableURL = URL(fileURLWithPath: commandName)
    if (commandName as NSString).isAbsolutePath, fileManager.isExecutableFile(atPath: executableURL.path) {
        return executableURL
    }

    // 检查命令是否在当前目录
    if let currentDirectoryURL = currentDirectoryURL {
        let currentDirectoryExecutable = currentDirectoryURL.appendingPathComponent(commandName)
        if FileManager.default.isExecutableFile(atPath: currentDirectoryExecutable.path) {
            return currentDirectoryExecutable
        }
    }

    // 然后检查命令是否在 PATH 环境变量中的某个目录
    if let path = path {
        let paths = path.split(separator: ":").map { String($0) }
        for p in paths {
            let potentialURL = URL(fileURLWithPath: p).appendingPathComponent(commandName)
            if FileManager.default.isExecutableFile(atPath: potentialURL.path) {
                return potentialURL
            }
        }
    }

    // 如果找不到可执行文件返回 nil
    return nil
}
