import AppKit
import Foundation
import Testing
import Yams
@testable import Selected

struct ContentActionsTests {
    @Test func pluginControlsItsOutputBehavior() {
        let plugin = Plugin.new()
        for kind in [ActionKind.gpt, .runCommand] {
            var action = Action.new(kind: kind)
            #expect(ActionRequest.plugin(plugin, action).output == (kind == .gpt ? .chat : .none))
            action.meta.after = AfterAction.none
            #expect(ActionRequest.plugin(plugin, action).output == (kind == .gpt ? .chat : .none))
            for (after, output) in [(AfterAction.copy, ActionRequest.Output.copy), (.paste, .paste), (.show, .show), (.xshow, .xshow)] {
                action.meta.after = after
                #expect(ActionRequest.plugin(plugin, action).output == output)
            }
        }
        for kind in [ActionKind.url, .service, .keycombo] {
            #expect(ActionRequest.plugin(plugin, .new(kind: kind)).output == .none)
        }
    }

    @Test @MainActor func nextPluginKeepsItsOwnBehavior() {
        var first = Action.new(kind: .runCommand)
        first.meta.after = .xshow
        let session = ActionSession(input: ActionInput(context: ActionInput.textContext("Original")),
                                    request: .plugin(Plugin.new(), first), target: ActionTarget(application: nil))
        session.output = "Result for AIChat"
        let chat = ActionRequest.plugin(Plugin.new(), .new(kind: .gpt))
        let next = ActionSession(input: chat.captureInput(session.input.replacingText(session.output)), request: chat,
                                 target: session.target, original: session.original)
        #expect(next.request.output == .chat)
        #expect(next.input.context.Text == "Result for AIChat")
        #expect(next.original.context.Text == "Original")
    }

    @Test @MainActor func catalogDoesNotProvideScenarioPresets() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        for text in ["A note", "https://example.com", "{\"value\":1}"] {
            #expect(ActionCatalog.entries(input: ActionInput(context: ActionInput.textContext(text)), manager: workspace.manager).isEmpty)
        }
    }

    @Test @MainActor func clipboardInputIsOptInAndRemainsSeparateFromPrimaryText() throws {
        let board = NSPasteboard(name: .init("Selected-InputTests-" + UUID().uuidString))
        defer { board.releaseGlobally() }
        board.setString("Clipboard reference", forType: .string)
        var action = Action.new(kind: .gpt)
        let context = SelectedTextContext(Text: "Primary input", ClipboardText: "Stale reference")
        #expect(action.captureContext(context, pasteboard: board).ClipboardText == nil)
        #expect(try action.prepareContext(context, options: [:]).ClipboardText == nil)
        action.meta.includeClipboard = true
        let captured = action.captureContext(context, pasteboard: board)
        #expect(captured.Text == "Primary input")
        #expect(captured.ClipboardText == "Clipboard reference")
        #expect(try action.prepareContext(captured, options: [:]).ClipboardText == "Clipboard reference")
        let decoded = try YAMLDecoder().decode(Action.self, from: YAMLEncoder().encode(action))
        #expect(decoded.meta.includeClipboard == true)
        action.setKind(.service)
        #expect(action.meta.includeClipboard == nil)
        action.meta.includeClipboard = true
        #expect(throws: PluginValidationError.self) { try Plugin(info: PluginInfo(), actions: [action]).validate() }
    }

    @Test @MainActor func templatesAndCommandsReceiveDeclaredClipboardInput() throws {
        let context = SelectedTextContext(Text: "Primary & input", ClipboardText: "Reference / 内容")
        var ai = Action.new(kind: .gpt)
        ai.meta.includeClipboard = true
        ai.gpt?.prompt = "{{ selected.text }} | {{ selected.clipboardText }}"
        #expect(try PluginTrial.preview(ai, plugin: Plugin.new(), context: context, values: [:]) == "Primary & input | Reference / 内容")
        ai.meta.includeClipboard = nil
        #expect(try PluginTrial.preview(ai, plugin: Plugin.new(), context: context, values: [:]) == "Primary & input | ")
        var url = Action.new(kind: .url)
        url.meta.includeClipboard = true
        url.url?.url = "https://example.com?input={selected.text}&clipboard={selected.clipboardText}"
        let preview = try PluginTrial.preview(url, plugin: Plugin.new(), context: context, values: [:])
        #expect(URLComponents(string: preview)?.queryItems == [URLQueryItem(name: "input", value: context.Text), URLQueryItem(name: "clipboard", value: context.ClipboardText)])
        var command = Action.new(kind: .runCommand)
        #expect(command.runCommand?.environment(pluginInfo: PluginInfo(), generic: command.meta, context: context)["SELECTED_CLIPBOARD_TEXT"] == nil)
        command.meta.includeClipboard = true
        #expect(command.runCommand?.environment(pluginInfo: PluginInfo(), generic: command.meta, context: context)["SELECTED_CLIPBOARD_TEXT"] == context.ClipboardText)
    }

    @Test @MainActor func retryUsesCapturedClipboardAndNextActionDropsUndeclaredReference() async throws {
        let board = NSPasteboard(name: .init("Selected-InputTests-" + UUID().uuidString))
        defer { board.releaseGlobally() }
        board.setString("First reference", forType: .string)
        var action = Action.new(kind: .runCommand)
        action.meta.includeClipboard = true
        action.runCommand?.command = ["/bin/sh", "-c", "printf '%s | %s' \"$SELECTED_TEXT\" \"$SELECTED_CLIPBOARD_TEXT\""]
        action.runCommand?.pluginPath = NSTemporaryDirectory()
        let request = ActionRequest.plugin(Plugin.new(), action)
        let input = request.captureInput(ActionInput(context: ActionInput.textContext("Primary")), pasteboard: board)
        let session = ActionSession(input: input, request: request, target: ActionTarget(application: nil))
        board.clearContents()
        board.setString("Changed reference", forType: .string)
        session.run()
        try await finish(session)
        #expect(session.output == "Primary | First reference")
        session.run()
        try await finish(session)
        #expect(session.output == "Primary | First reference")
        var next = Action.new(kind: .runCommand)
        next.runCommand?.pluginPath = NSTemporaryDirectory()
        let nextRequest = ActionRequest.plugin(Plugin.new(), next)
        let nextInput = nextRequest.captureInput(session.input.replacingText(session.output), pasteboard: board)
        let nextSession = ActionSession(input: nextInput, request: nextRequest, target: session.target, original: session.original)
        nextSession.run()
        try await finish(nextSession)
        #expect(nextSession.output == "Primary | First reference")
        #expect(nextSession.input.reference == nil)
        #expect(nextSession.original.reference == "First reference")
    }

    @Test func continuingWithTextDropsAttachmentsAndRecomputesContentKind() {
        var input = ActionInput(context: ActionInput.textContext("Attachment"))
        input.items = [ClipItem(type: .png, data: Data([1]))]
        let next = input.replacingText("https://example.com")
        #expect(!next.hasAttachment)
        #expect(next.kind == .link)
        #expect(next.context.URLs == ["https://example.com"])
    }

    @Test func separatePasteTargetDoesNotInventAnEditableSource() throws {
        var action = Action.new(kind: .gpt)
        action.meta.after = .paste
        let context = SelectedTextContext(Text: "Clipboard input", Editable: false)
        #expect(throws: PluginValidationError.self) { try action.prepareContext(context, options: [:]) }
        #expect(try action.prepareContext(context, options: [:], separatePasteTarget: true).Editable == false)
        action.meta.requirements = [.editable]
        #expect(throws: PluginValidationError.self) { try action.prepareContext(context, options: [:], separatePasteTarget: true) }
    }

    @Test @MainActor func catalogRespectsPluginReadinessMatchingAndInputKinds() throws {
        let workspace = try PluginTestWorkspace()
        defer { workspace.cleanUp() }
        var plugin = Plugin.new()
        plugin.actions = [.new(kind: .gpt), .new(kind: .keycombo), .new(kind: .runCommand)]
        plugin.actions[0].meta.after = .paste
        plugin.actions[2].meta.regex = "^code:"
        try workspace.manager.save(plugin, replacing: nil)
        var input = ActionInput(context: ActionInput.textContext("A note"))
        let list = ActionCatalog.entries(input: input, manager: workspace.manager)
        #expect(list.contains { $0.id == "plugin:" + plugin.actions[0].meta.identifier })
        #expect(!list.contains { $0.id == "plugin:" + plugin.actions[1].meta.identifier || $0.id == "plugin:" + plugin.actions[2].meta.identifier })
        #expect(list.count == 1)
        input.items = [ClipItem(type: .png, data: Data([1]))]
        let attachmentList = ActionCatalog.entries(input: input, manager: workspace.manager)
        #expect(attachmentList.contains { $0.id == "plugin:" + plugin.actions[0].meta.identifier })
        #expect(!attachmentList.contains { $0.id == "plugin:" + plugin.actions[2].meta.identifier })
        plugin.info.options = [Option(identifier: "endpoint", type: .string, required: true)]
        plugin.info.version = "1.0.1"
        let installed = try #require(workspace.manager.plugins.first)
        try workspace.manager.save(plugin, replacing: installed)
        #expect(!ActionCatalog.entries(input: input, manager: workspace.manager).contains { $0.id == "plugin:" + plugin.actions[0].meta.identifier })
    }

    @Test @MainActor func sessionRetainsOriginalAndUsesEditedResultForNextAction() async throws {
        let input = ActionInput(context: ActionInput.textContext("Original input"))
        var action = Action.new(kind: .runCommand)
        action.runCommand?.pluginPath = NSTemporaryDirectory()
        let request = ActionRequest.plugin(Plugin.new(), action)
        let session = ActionSession(input: input, request: request, target: ActionTarget(application: nil))
        session.run()
        try await finish(session)
        #expect(session.output == "Original input")
        session.output = "Edited result"
        let nextSession = ActionSession(input: request.captureInput(session.input.replacingText(session.output)), request: request,
                                        target: session.target, original: session.original)
        nextSession.run()
        try await finish(nextSession)
        #expect(nextSession.output == "Edited result")
        #expect(nextSession.input.context.Text == "Edited result")
        #expect(nextSession.original.context.Text == "Original input")
        nextSession.run()
        try await finish(nextSession)
        #expect(nextSession.output == "Edited result")
    }

    @Test @MainActor func commandSessionCancelsAndRetriesWithSameInput() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let script = folder.appendingPathComponent("action.sh")
        try "exec /bin/sleep 20".write(to: script, atomically: true, encoding: .utf8)
        var action = Action.new(kind: .runCommand)
        action.runCommand?.command = ["/bin/sh", script.path]
        action.runCommand?.pluginPath = folder.path
        let input = ActionInput(context: ActionInput.textContext("A fixed input"))
        let session = ActionSession(input: input, request: .plugin(Plugin.new(), action), target: ActionTarget(application: nil))
        session.run()
        try await Task.sleep(for: .milliseconds(80))
        session.cancel()
        try await finish(session)
        #expect(!session.completed)
        #expect(!session.failed)
        try "printf '%s' \"$SELECTED_TEXT\"".write(to: script, atomically: true, encoding: .utf8)
        session.run()
        try await finish(session)
        #expect(session.completed)
        #expect(session.output == "A fixed input")
        #expect(session.original.context.Text == "A fixed input")
    }

    @Test @MainActor func failedCommandsDoNotExposePartialOutput() async throws {
        var action = Action.new(kind: .runCommand)
        action.runCommand?.command = ["/bin/sh", "-c", "printf partial; printf broken >&2; exit 3"]
        action.runCommand?.pluginPath = NSTemporaryDirectory()
        let input = ActionInput(context: ActionInput.textContext("Keep this input"))
        let session = ActionSession(input: input, request: .plugin(Plugin.new(), action), target: ActionTarget(application: nil))
        session.run()
        try await finish(session)
        #expect(session.failed)
        #expect(!session.completed)
        #expect(session.output.isEmpty)
        #expect(session.message.contains("broken"))
        #expect(session.input.context.Text == "Keep this input")
    }

    @MainActor private func finish(_ session: ActionSession) async throws {
        for _ in 0..<300 {
            if !session.isRunning { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        session.cancel()
        Issue.record("Content action did not finish in time")
    }
}
