import Foundation

func getCurrentAppLanguage() -> String {
    if let languageCode = Locale.preferredLanguages.first {
        let locale = Locale.current
        if let language = locale.localizedString(forLanguageCode: languageCode) {
            return language
        }
    }
    return "English"
}
