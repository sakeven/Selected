import Foundation

extension Action {
    func generate(pluginInfo: PluginInfo) -> PerformAction? {
        var generic = meta
        generic.title = PluginTemplate.render(generic.title, context: SelectedTextContext(), options: pluginInfo.getOptionsValue())
        let generated: PerformAction?
        switch kind {
        case .url: generated = url?.generate(pluginInfo: pluginInfo, generic: generic, popclip: popclip)
        case .service: generated = service?.generate(generic: generic)
        case .keycombo: generated = keycombo?.generate(pluginInfo: pluginInfo, generic: generic, popclip: popclip)
        case .gpt: generated = gpt?.generate(pluginInfo: pluginInfo, generic: generic)
        case .runCommand: generated = runCommand?.generate(pluginInfo: pluginInfo, generic: generic)
        }
        if let generated {
            generated.pluginInfo = pluginInfo
            let values = pluginInfo.getOptionsValue()
            let options = popclip == nil ? values : PopClipAction.optionValues(pluginInfo, values: values)
            generated.supported = { (try? self.prepareContext($0, options: options)) != nil }
            if let complete = generated.complete {
                generated.complete = { context in
                    let context = MainActor.assumeIsolated { self.captureContext(context) }
                    guard let prepared = try? self.prepareContext(context, options: options) else { return }
                    complete(prepared)
                }
            }
            if let complete = generated.completeAsync {
                generated.completeAsync = { context in
                    let context = await MainActor.run { self.captureContext(context) }
                    guard let prepared = try? self.prepareContext(context, options: options) else { return }
                    await complete(prepared)
                }
            }
            return generated
        }
        return nil
    }
}
