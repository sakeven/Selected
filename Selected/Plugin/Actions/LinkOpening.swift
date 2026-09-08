import Foundation
import AppKit

extension URL {
    func setScheme(_ value: String) -> URL {
        guard let components = NSURLComponents.init(url: self, resolvingAgainstBaseURL: true) else {
            return self
        }
        components.scheme = value
        return components.url ?? self
    }
}

func openActionURL(_ url: URL, bundleID: String) {
    if url.scheme != "http" && url.scheme != "https" {
        // not a web link
        NSWorkspace.shared.open(url)
        return
    }

    if !isBrowser(id: bundleID){
        NSWorkspace.shared.open(url)
        return
    }

    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
        NSWorkspace.shared.open(url)
        return
    }

    let cfg =  NSWorkspace.OpenConfiguration()
    cfg.activates = true
    NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: cfg)
}
