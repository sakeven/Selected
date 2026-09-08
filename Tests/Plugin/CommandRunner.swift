import Foundation
import Testing
@testable import Selected

struct CommandRunnerTests {
    @Test func resolvesAbsoluteThenWorkingDirectoryThenSearchPath() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("command-lookup-\(UUID())")
        let work = folder.appendingPathComponent("work"), path = folder.appendingPathComponent("path")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let local = work.appendingPathComponent("fixture"), searched = path.appendingPathComponent("fixture")
        for url in [local, searched] {
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        }
        #expect(findExecutablePath(commandName: "/usr/bin/true", currentDirectoryURL: work, path: path.path)?.path == "/usr/bin/true")
        #expect(findExecutablePath(commandName: "fixture", currentDirectoryURL: work, path: path.path) == local)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: local.path)
        #expect(findExecutablePath(commandName: "fixture", currentDirectoryURL: work, path: path.path) == searched)
        #expect(findExecutablePath(commandName: "missing", currentDirectoryURL: work, path: path.path) == nil)
    }

    @Test func keepsArgumentsEnvironmentAndWorkingDirectoryWithoutShellExpansion() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("command-fixture-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = try executeCommandResult(workdir: folder.path, command: "/bin/sh", arguments: ["-c", "printf '%s\\n' \"$1\" \"$FIXTURE_VALUE\"; pwd", "fixture", "$(printf expanded)"], withEnv: ["FIXTURE_VALUE": "Hello 世界"])
        let lines = result.output.split(separator: "\n").map(String.init)
        #expect(result.exitCode == 0)
        #expect(result.diagnostics.isEmpty)
        #expect(lines.prefix(2) == ["$(printf expanded)", "Hello 世界"])
        let actualDirectory = try #require(lines.last).withCString { realpath($0, nil) }
        let expectedDirectory = folder.path.withCString { realpath($0, nil) }
        defer { free(actualDirectory); free(expectedDirectory) }
        #expect(try String(cString: #require(actualDirectory)) == String(cString: #require(expectedDirectory)))
    }

    @Test func missingExecutableKeepsErrorCode127() {
        do {
            _ = try executeCommandResult(workdir: "/tmp", command: "selected-missing-\(UUID())", withEnv: [:])
            Issue.record("Missing executable unexpectedly ran")
        } catch {
            #expect((error as NSError).domain == "Selected.Command")
            #expect((error as NSError).code == 127)
        }
    }
}
