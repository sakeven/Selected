import Foundation
import AppKit

struct Action: Codable, Identifiable {
    var id = UUID()
    enum CodingKeys: String, CodingKey {
        case meta, url, service, keycombo, gpt, runCommand, popclip
    }
    var meta: GenericAction
    var url: URLAction?
    var service: ServiceAction?
    var keycombo: KeycomboAction?
    var gpt: GptAction?
    var runCommand: RunCommandAction?
    var popclip: PopClipAction?
}
