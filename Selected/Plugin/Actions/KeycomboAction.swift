import Foundation
import AppKit

struct KeycomboAction: Codable {
    var keycombo: String = ""
    var keycombos: [String]?

    var supported: Supported? // supported urls or apps

    init(keycombo: String) {
        NSLog("set keycombo \(keycombo)")
        self.keycombo = keycombo
    }

    init(keycombos: [String]) {
        NSLog("set keycombos \(keycombos)")
        self.keycombos = keycombos
        self.keycombo = ""
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        keycombo = try values.decodeIfPresent(String.self, forKey: .keycombo) ?? ""
        keycombos = try values.decodeIfPresent([String].self, forKey: .keycombos)
        supported = try values.decodeIfPresent(Supported.self, forKey: .supported)
    }

    func pressKeycombo(keycombo: String, tap: CGEventTapLocation = .cghidEventTap) {
        let combination = KeyCombination(keycombo)
        PressKey(keycode: combination.keycode, flags: combination.flags, tap: tap)
    }

    private func isMatched(bundleID: String, url: String) -> Bool {
        guard let supported = self.supported else{
            return true
        }
       return supported.match(url: url, bundleID: bundleID)
    }

    func supported(ctx: SelectedTextContext) -> Bool {
        return isMatched(bundleID: ctx.BundleID, url: ctx.WebPageURL)
    }

    func generate(pluginInfo: PluginInfo, generic: GenericAction, popclip: PopClipAction? = nil) -> PerformAction {
        let pa = PerformAction(pluginInfo: pluginInfo, actionMeta:
                                generic, complete: { ctx in
            if let keycombos = self.keycombos, !keycombos.isEmpty {
                for keycombo in keycombos {
                    self.pressKeycombo(keycombo: keycombo, tap: popclip?.keyComboTarget == "session" ? .cgSessionEventTap : .cghidEventTap)
                    usleep(100000)
                }
            } else {
                self.pressKeycombo(keycombo: self.keycombo, tap: popclip?.keyComboTarget == "session" ? .cgSessionEventTap : .cghidEventTap)
            }
        })
        pa.supported = self.supported
        return pa
    }
}
