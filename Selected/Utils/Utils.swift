//
//  Utils.swift
//  Selected
//
//  Created by sake on 2024/3/13.
//

import AppKit

func PressCopyKey() {
    PressKey(keycode: Keycode.c, flags: .maskCommand)
}

func PressPasteKey() {
    PressKey(keycode: Keycode.v, flags: .maskCommand)
}

func PressKey(keycode: CGKeyCode) {
    guard let keydownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: true) else{return}
    keydownEvent.post(tap: .cghidEventTap)

    guard let keyupEvent = CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: false) else{return}
    keyupEvent.post(tap: .cghidEventTap)
}


func PressKey(keycode: CGKeyCode, flags: CGEventFlags) {
    guard let keydownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: true) else{return}

    keydownEvent.flags = flags
    keydownEvent.post(tap: .cghidEventTap)


    guard let keyupEvent = CGEvent(keyboardEventSource: nil, virtualKey: keycode, keyDown: false) else{return}

    keyupEvent.flags = flags
    keyupEvent.post(tap: .cghidEventTap)
}

func PerfomService(serviceName: String, text: String) {
    let pBoard = NSPasteboard(name: NSPasteboard.Name(rawValue: "pasteBoard_\(UUID().uuidString)"))
    pBoard.setString(text, forType: .string)
    NSPerformService(serviceName, pBoard)
    // TODO need release?
    pBoard.releaseGlobally()
}

let KeyMaskMapping: [String: CGEventFlags] = [
    "cmd":    .maskCommand,
    "shift":  .maskShift,
    "ctr":    .maskControl,
    "option": .maskAlternate,
    "alt":    .maskAlternate,
    "fn":     .maskSecondaryFn,
    "caps":   .maskAlphaShift,
]

let KeycodeMapping: [String: UInt16] = [
    "a"                         : 0x00,
    "b"                         : 0x0B,
    "c"                         : 0x08,
    "d"                         : 0x02,
    "e"                         : 0x0E,
    "f"                         : 0x03,
    "g"                         : 0x05,
    "h"                         : 0x04,
    "i"                         : 0x22,
    "j"                         : 0x26,
    "k"                         : 0x28,
    "l"                         : 0x25,
    "m"                         : 0x2E,
    "n"                         : 0x2D,
    "o"                         : 0x1F,
    "p"                         : 0x23,
    "q"                         : 0x0C,
    "r"                         : 0x0F,
    "s"                         : 0x01,
    "t"                         : 0x11,
    "u"                         : 0x20,
    "v"                         : 0x09,
    "w"                         : 0x0D,
    "x"                         : 0x07,
    "y"                         : 0x10,
    "z"                         : 0x06,

    "0"                         : 0x1D,
    "1"                         : 0x12,
    "2"                         : 0x13,
    "3"                         : 0x14,
    "4"                         : 0x15,
    "5"                         : 0x17,
    "6"                         : 0x16,
    "7"                         : 0x1A,
    "8"                         : 0x1C,
    "9"                         : 0x19,

    "="                         : 0x18,
    "-"                         : 0x1B,
    ";"                         : 0x29,
    "'"                         : 0x27,
    ","                         : 0x2B,
    "."                         : 0x2F,
    "/"                         : 0x2C,
    "\\"                        : 0x2A,
    "`"                         : 0x32,
    "["                         : 0x21,
    "]"                         : 0x1E,
]

// from https://gist.github.com/swillits/df648e87016772c7f7e5dbed2b345066
struct Keycode {

    // Layout-independent Keys
    // eg.These key codes are always the same key on all layouts.
    static let returnKey                 : UInt16 = 0x24
    static let enter                     : UInt16 = 0x4C
    static let tab                       : UInt16 = 0x30
    static let space                     : UInt16 = 0x31
    static let delete                    : UInt16 = 0x33
    static let escape                    : UInt16 = 0x35
    static let command                   : UInt16 = 0x37
    static let shift                     : UInt16 = 0x38
    static let capsLock                  : UInt16 = 0x39
    static let option                    : UInt16 = 0x3A
    static let control                   : UInt16 = 0x3B
    static let rightCommand              : UInt16 = 0x36
    static let rightShift                : UInt16 = 0x3C
    static let rightOption               : UInt16 = 0x3D
    static let rightControl              : UInt16 = 0x3E
    static let leftArrow                 : UInt16 = 0x7B
    static let rightArrow                : UInt16 = 0x7C
    static let downArrow                 : UInt16 = 0x7D
    static let upArrow                   : UInt16 = 0x7E
    static let volumeUp                  : UInt16 = 0x48
    static let volumeDown                : UInt16 = 0x49
    static let mute                      : UInt16 = 0x4A
    static let help                      : UInt16 = 0x72
    static let home                      : UInt16 = 0x73
    static let pageUp                    : UInt16 = 0x74
    static let forwardDelete             : UInt16 = 0x75
    static let end                       : UInt16 = 0x77
    static let pageDown                  : UInt16 = 0x79
    static let function                  : UInt16 = 0x3F
    static let f1                        : UInt16 = 0x7A
    static let f2                        : UInt16 = 0x78
    static let f4                        : UInt16 = 0x76
    static let f5                        : UInt16 = 0x60
    static let f6                        : UInt16 = 0x61
    static let f7                        : UInt16 = 0x62
    static let f3                        : UInt16 = 0x63
    static let f8                        : UInt16 = 0x64
    static let f9                        : UInt16 = 0x65
    static let f10                       : UInt16 = 0x6D
    static let f11                       : UInt16 = 0x67
    static let f12                       : UInt16 = 0x6F
    static let f13                       : UInt16 = 0x69
    static let f14                       : UInt16 = 0x6B
    static let f15                       : UInt16 = 0x71
    static let f16                       : UInt16 = 0x6A
    static let f17                       : UInt16 = 0x40
    static let f18                       : UInt16 = 0x4F
    static let f19                       : UInt16 = 0x50
    static let f20                       : UInt16 = 0x5A

    // US-ANSI Keyboard Positions
    // eg. These key codes are for the physical key (in any keyboard layout)
    // at the location of the named key in the US-ANSI layout.
    static let a                         : UInt16 = 0x00
    static let b                         : UInt16 = 0x0B
    static let c                         : UInt16 = 0x08
    static let d                         : UInt16 = 0x02
    static let e                         : UInt16 = 0x0E
    static let f                         : UInt16 = 0x03
    static let g                         : UInt16 = 0x05
    static let h                         : UInt16 = 0x04
    static let i                         : UInt16 = 0x22
    static let j                         : UInt16 = 0x26
    static let k                         : UInt16 = 0x28
    static let l                         : UInt16 = 0x25
    static let m                         : UInt16 = 0x2E
    static let n                         : UInt16 = 0x2D
    static let o                         : UInt16 = 0x1F
    static let p                         : UInt16 = 0x23
    static let q                         : UInt16 = 0x0C
    static let r                         : UInt16 = 0x0F
    static let s                         : UInt16 = 0x01
    static let t                         : UInt16 = 0x11
    static let u                         : UInt16 = 0x20
    static let v                         : UInt16 = 0x09
    static let w                         : UInt16 = 0x0D
    static let x                         : UInt16 = 0x07
    static let y                         : UInt16 = 0x10
    static let z                         : UInt16 = 0x06

    static let zero                      : UInt16 = 0x1D
    static let one                       : UInt16 = 0x12
    static let two                       : UInt16 = 0x13
    static let three                     : UInt16 = 0x14
    static let four                      : UInt16 = 0x15
    static let five                      : UInt16 = 0x17
    static let six                       : UInt16 = 0x16
    static let seven                     : UInt16 = 0x1A
    static let eight                     : UInt16 = 0x1C
    static let nine                      : UInt16 = 0x19

    static let equals                    : UInt16 = 0x18
    static let minus                     : UInt16 = 0x1B
    static let semicolon                 : UInt16 = 0x29
    static let apostrophe                : UInt16 = 0x27
    static let comma                     : UInt16 = 0x2B
    static let period                    : UInt16 = 0x2F
    static let forwardSlash              : UInt16 = 0x2C
    static let backslash                 : UInt16 = 0x2A
    static let grave                     : UInt16 = 0x32
    static let leftBracket               : UInt16 = 0x21
    static let rightBracket              : UInt16 = 0x1E

    static let keypadDecimal             : UInt16 = 0x41
    static let keypadMultiply            : UInt16 = 0x43
    static let keypadPlus                : UInt16 = 0x45
    static let keypadClear               : UInt16 = 0x47
    static let keypadDivide              : UInt16 = 0x4B
    static let keypadEnter               : UInt16 = 0x4C
    static let keypadMinus               : UInt16 = 0x4E
    static let keypadEquals              : UInt16 = 0x51
    static let keypad0                   : UInt16 = 0x52
    static let keypad1                   : UInt16 = 0x53
    static let keypad2                   : UInt16 = 0x54
    static let keypad3                   : UInt16 = 0x55
    static let keypad4                   : UInt16 = 0x56
    static let keypad5                   : UInt16 = 0x57
    static let keypad6                   : UInt16 = 0x58
    static let keypad7                   : UInt16 = 0x59
    static let keypad8                   : UInt16 = 0x5B
    static let keypad9                   : UInt16 = 0x5C
}


func replaceOptions(content: String, selectedText: String, options: [String:String]? = nil) -> String {
    var message = content
    message.replace("{selected.text}", with: selectedText)
    if let options = options {
        for option in options {
            message.replace("{selected.options."+option.key+"}", with: option.value)
        }
    }
    return message
}


var valueFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .none
    formatter.maximumFractionDigits = 2
    return formatter
}()


func getCurrentAppLanguage() -> String {
    if let languageCode = Locale.preferredLanguages.first {
        let locale = Locale.current
        if let language = locale.localizedString(forLanguageCode: languageCode) {
            return language
        }
    }
    return "English"
}


func jsonify(_ jsonString: String) -> String {
    // 1. 将 JSON 字符串转换为 UTF-8 编码的 Data
    guard let jsonData = jsonString.data(using: .utf8) else {
        return jsonString
    }
    do {
        // 2. 使用 JSONSerialization 将 Data 解析为字典
        if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            // 3. 重新编码为 JSON 字符串
            let prettyJsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
            if let prettyPrintedString = String(data: prettyJsonData, encoding: .utf8) {
                // 打印最终解码后的 JSON 字符串
                return prettyPrintedString
            } else {
                print("Failed to convert data to string.")
            }
        } else {
            print("Failed to parse JSON.")
        }
    } catch {
        print("Error deserializing JSON: \(error.localizedDescription)")
    }
    return jsonString
}

func createTemporaryURLForData(_ data: Data, fileName: String) -> URL? {
    // 获取临时目录 URL
    let tempDirectoryURL = FileManager.default.temporaryDirectory

    // 创建新临时文件 URL
    let tempFileURL = tempDirectoryURL.appendingPathComponent(fileName)

    do {
        // 将数据写入临时文件
        try data.write(to: tempFileURL)
        return tempFileURL
    } catch {
        print("Error writing data to temporary file: \(error)")
        return nil
    }
}
