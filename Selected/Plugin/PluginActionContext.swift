import AppKit

extension Action {
    @MainActor func captureContext(_ context: SelectedTextContext, pasteboard: NSPasteboard = .general) -> SelectedTextContext {
        var result = context
        result.ClipboardText = meta.includeClipboard == true ? pasteboard.string(forType: .string) ?? "" : nil
        return result
    }

    func prepareContext(_ context: SelectedTextContext, options: [String: String], separatePasteTarget: Bool = false) throws -> SelectedTextContext {
        var context = context
        if meta.includeClipboard != true { context.ClipboardText = nil }
        if let reason = meta.unavailableReason(context) {
            throw PluginValidationError(messages: [reason])
        }
        if let keycombo, !keycombo.supported(ctx: context) {
            throw PluginValidationError(messages: [String(localized: "This app or webpage is excluded by the shortcut's matching rules.")])
        }
        if !separatePasteTarget && meta.after == .paste && !context.Editable {
            throw PluginValidationError(messages: [String(localized: "This action requires an editable text field.")])
        }
        return try popclip?.prepare(context, options: options) ?? context
    }

    func renderedURL(context: SelectedTextContext, options: [String: String], exactPhrase: Bool = false) -> String {
        guard let url else { return "" }
        return popclip?.renderURL(url.url, context: context, options: options, exactPhrase: exactPhrase)
            ?? PluginTemplate.render(url.url, context: context, options: options, urlEncoded: true)
    }
}
