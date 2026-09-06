import AppKit
import Defaults
import Observation
import Stencil

@MainActor @Observable final class PluginTrial {
    private(set) var output = ""
    private(set) var diagnostics = ""
    private(set) var status = ""
    private(set) var failed = false
    private(set) var duration: TimeInterval?
    private(set) var isRunning = false
    @ObservationIgnored private var task: Task<Void, Never>?

    static func prepared(_ action: Action, plugin: Plugin, context: SelectedTextContext, values: [String: String]) throws -> SelectedTextContext {
        let missing = plugin.info.missingOptions(values: values)
        guard missing.isEmpty else {
            throw PluginValidationError(messages: [String(localized: "Configure these required options first: \(missing.map(\.displayName).joined(separator: ", "))")])
        }
        let options = action.popclip == nil ? values : PopClipAction.optionValues(plugin.info, values: values)
        return try action.prepareContext(context, options: options)
    }

    static func preview(_ action: Action, plugin: Plugin, context: SelectedTextContext, values: [String: String]) throws -> String {
        let context = try prepared(action, plugin: plugin, context: context, values: values)
        let options = action.popclip == nil ? values : PopClipAction.optionValues(plugin.info, values: values)
        let preview: String
        switch action.kind {
        case .url: preview = action.renderedURL(context: context, options: options)
        case .gpt:
            let chat = ChatContext(text: context.Text, webPageURL: context.WebPageURL, bundleID: context.BundleID, clipboardText: context.ClipboardText ?? "")
            let template = try Environment(loader: nil, trimBehaviour: .all).renderTemplate(string: action.gpt!.prompt, context: ["selected": chat, "options": options])
            preview = replaceOptions(content: template, selectedText: context.Text, options: options)
        case .runCommand:
            preview = (action.runCommand?.command.joined(separator: "\n") ?? "") + "\n\nSELECTED_TEXT:\n" + context.Text
                + (context.ClipboardText.map { "\n\nSELECTED_CLIPBOARD_TEXT:\n" + $0 } ?? "")
        case .service: preview = (action.service?.name ?? "") + "\n\n" + context.Text
        case .keycombo: preview = action.keycombo?.keycombos?.joined(separator: " → ") ?? action.keycombo?.keycombo ?? ""
        }
        return PluginRedactor(info: plugin.info, values: values).redact(preview)
    }

    func run(_ action: Action, plugin: Plugin, context: SelectedTextContext, directory: URL) {
        guard !isRunning else { return }
        output = ""
        diagnostics = ""
        status = String(localized: "Running…")
        failed = false
        duration = nil
        isRunning = true
        task = Task {
            let start = Date()
            let values = plugin.info.getOptionsValue()
            let redactor = PluginRedactor(info: plugin.info, values: values)
            defer { duration = Date().timeIntervalSince(start); isRunning = false; task = nil }
            do {
                let prepared = try Self.prepared(action, plugin: plugin, context: context, values: values)
                if let command = action.runCommand, let executable = command.command.first {
                    let cancellation = CommandCancellation()
                    let environment = command.environment(pluginInfo: plugin.info, generic: action.meta, context: prepared)
                    let result = try await withTaskCancellationHandler {
                        try await Task.detached {
                            try executeCommandResult(workdir: directory.path, command: executable, arguments: Array(command.command.dropFirst()), withEnv: environment, cancellation: cancellation)
                        }.value
                    } onCancel: { cancellation.cancel() }
                    try Task.checkCancellation()
                    output = redactor.redact(result.output)
                    diagnostics = redactor.redact(result.diagnostics)
                    failed = result.exitCode != 0
                    status = String(localized: "Command exit code: \(result.exitCode)")
                } else if let ai = action.gpt {
                    let key = Defaults[.aiService] == "OpenAI" ? Defaults[.openAIAPIKey] : Defaults[.claudeAPIKey]
                    guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw PluginValidationError(messages: [String(localized: "Set up your AI provider and API key in General settings first.")])
                    }
                    var tools = ai.tools
                    for index in tools?.indices ?? 0..<0 { tools?[index].workdir = directory.path }
                    guard let service = ChatService(prompt: ai.prompt, tools: tools, options: values, reasoning: ai.reasoning ?? (action.meta.after == nil || action.meta.after == AfterAction.none)) else {
                        throw PluginValidationError(messages: [String(localized: "Set up your AI provider and API key in General settings first.")])
                    }
                    var response = ""
                    let context = ChatContext(text: prepared.Text, webPageURL: prepared.WebPageURL, bundleID: prepared.BundleID, clipboardText: prepared.ClipboardText ?? "")
                    for try await event in service.chat(ctx: context) {
                        try Task.checkCancellation()
                        if case .textDelta(let text) = event { response += text }
                        if case .error(let message) = event { throw PluginValidationError(messages: [message]) }
                    }
                    try Task.checkCancellation()
                    output = redactor.redact(response)
                    status = String(localized: "Completed")
                } else {
                    output = try Self.preview(action, plugin: plugin, context: context, values: values)
                    status = String(localized: "Preview ready")
                }
            } catch is CancellationError {
                status = String(localized: "Cancelled")
            } catch {
                if Task.isCancelled { status = String(localized: "Cancelled") }
                else {
                    failed = true
                    status = String(localized: "Run failed")
                    diagnostics = redactor.redact(error.localizedDescription)
                }
            }
        }
    }

    func cancel() { task?.cancel() }
}
