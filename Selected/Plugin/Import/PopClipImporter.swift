import AppKit
import Yams

struct PopClipImporter {
    static func inspect(_ url: URL) throws -> PopClipImport {
        let result = try PopClipImport(sourceName: url.lastPathComponent)
        do {
            let fm = FileManager.default
            let original = result.directory.appendingPathComponent("PopClip Source", isDirectory: true)
            try fm.createDirectory(at: original, withIntermediateDirectories: true)
            let package: URL
            if url.pathExtension.lowercased() == "popclipextz" {
                let summary = try executeCommand(workdir: original.path, command: "/usr/bin/zipinfo", arguments: ["-t", url.path], withEnv: ["LC_ALL": "C"]) ?? ""
                let expression = try NSRegularExpression(pattern: #"(\d+) files?, (\d+) bytes uncompressed"#)
                guard let match = expression.firstMatch(in: summary, range: NSRange(summary.startIndex..., in: summary)),
                      let range = Range(match.range(at: 2), in: summary), let size = Int(summary[range]), size <= 50 * 1024 * 1024 else {
                    throw PluginValidationError(messages: [String(localized: "The plugin package exceeds the 50 MB import limit.")])
                }
                let listing = try executeCommand(workdir: original.path, command: "/usr/bin/tar", arguments: ["-tf", url.path], withEnv: [:]) ?? ""
                let paths = listing.split(whereSeparator: \.isNewline).map(String.init)
                guard !paths.isEmpty, paths.allSatisfy({ !$0.hasPrefix("/") && !$0.split(separator: "/").contains("..") }) else {
                    throw PluginValidationError(messages: [String(localized: "The archive contains an invalid resource path.")])
                }
                // bsdtar rejects traversal through symlinks while extracting.
                _ = try executeCommand(workdir: original.path, command: "/usr/bin/tar", arguments: ["-xf", url.path, "--no-same-owner", "--no-same-permissions"], withEnv: [:])
                let packages = try fm.contentsOfDirectory(at: original, includingPropertiesForKeys: nil).filter { $0.pathExtension == "popclipext" }
                guard packages.count == 1 else {
                    throw PluginValidationError(messages: [String(localized: "Choose an archive containing exactly one .popclipext package.")])
                }
                package = packages[0]
            } else {
                try validateResources(url)
                package = original.appendingPathComponent(url.lastPathComponent)
                try fm.copyItem(at: url, to: package)
            }
            try validateResources(original)
            let configs = try fm.contentsOfDirectory(at: package, includingPropertiesForKeys: nil).filter {
                ["Config.yaml", "Config.json", "Config.plist", "Config.js", "Config.ts"].contains($0.lastPathComponent)
            }
            guard configs.count == 1, let config = configs.first else {
                throw PluginValidationError(messages: [String(localized: "Expected one Config.yaml, Config.json, or Config.plist file.")])
            }
            guard !["js", "ts"].contains(config.pathExtension) else {
                throw PluginValidationError(messages: [String(localized: "JavaScript and TypeScript plugins are not supported yet.")])
            }
            let data = try Data(contentsOf: config)
            let object: Any?
            if config.pathExtension == "plist" {
                object = try PropertyListSerialization.propertyList(from: data, format: nil)
            } else {
                object = try Yams.load(yaml: String(decoding: data, as: UTF8.self))
            }
            guard let dictionary = object as? [String: Any] else {
                throw PluginValidationError(messages: [String(localized: "The PopClip configuration must be a dictionary.")])
            }
            var importer = PopClipParser(package: package, result: result)
            result.plugin = try importer.parse(dictionary)
        } catch {
            result.issues.append(error.localizedDescription)
        }
        return result
    }

    private static func validateResources(_ directory: URL) throws {
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey]
        var urls = [directory]
        if let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: Array(keys)) {
            urls += enumerator.allObjects.compactMap { $0 as? URL }
        }
        var size = 0
        for url in urls {
            let values = try url.resourceValues(forKeys: keys)
            guard values.isSymbolicLink != true, values.isRegularFile == true || values.isDirectory == true else {
                throw PluginValidationError(messages: [String(localized: "Plugin resources must be regular files or folders, without symbolic links.")])
            }
            size += values.fileSize ?? 0
            guard size <= 50 * 1024 * 1024 else {
                throw PluginValidationError(messages: [String(localized: "The plugin package exceeds the 50 MB import limit.")])
            }
        }
    }
}
