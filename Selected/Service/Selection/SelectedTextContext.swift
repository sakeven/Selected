import Foundation

struct SelectedTextContext {
    var Text: String = ""
    var BundleID: String = ""
    var WebPageURL: String = "" // the url of webpage which contains text.
    var URLs = [String]() // all urls in text
    var Address: String = "" // last address in text
    var Editable: Bool = false // 当前窗口是否可编辑。浏览器里的怎么判断？
    var ClipboardText: String?
    // TODO: IDE 或者 Editor 下，获取当前编辑文件名、行号等
}

extension SelectedTextContext: CustomStringConvertible {
    var description: String {
        return "SelectedTextContext(Text: \(Text), BundleID: \(BundleID))"
    }
}

extension SelectedTextContext {
    mutating func readDetectedContent(from selectedText: String) {
        // get urls from selected text.
        let detector = try! NSDataDetector(types:
                                            NSTextCheckingResult.CheckingType.link.rawValue |
                                           NSTextCheckingResult.CheckingType.address.rawValue
        )
        let matches = detector.matches(in: selectedText, options: [], range: NSRange(location: 0, length: selectedText.count))
        var urlSet = Set<String>()
        var address = ""
        for match in matches {
            guard let range = Range(match.range, in: selectedText) else { continue }

            let item = String(selectedText[range])
            if match.resultType == .link {
                urlSet.insert(item)
            } else if match.resultType == .address {
                address = item
            }
        }
        self.URLs = Array(urlSet)
        self.Address = address
        self.Text = selectedText
    }
}
