import AppKit

struct KeyCombination {
    private(set) var flags = CGEventFlags(rawValue: 0)
    private(set) var keycode = UInt16(0)

    init(_ value: String) {
        let list = value.split(separator: " ")
        list.forEach { sub in
            let str = String(sub)
            if let mask = KeyMaskMapping[str]{
                flags.insert(mask)
            }
            if let key = KeycodeMapping[str] {
                keycode = key
            }
        }
    }
}
