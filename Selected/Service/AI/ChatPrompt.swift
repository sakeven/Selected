import Foundation

func systemPrompt() -> String{
    let language = getCurrentAppLanguage()
    var currentLocation = ""
    if let location = LocationManager.shared.place {
        currentLocation = "I'm at \(location)"
    }
    return """
                      You are a tool running on macOS called Selected. You can help user do anything.
                      The system language is \(language), you should try to reply in \(language) as much as possible, unless the user specifies to use another language, such as specifying to translate into a certain language.
                      When you need to output formulas, if it is a block formula, you should use the format $$a=b$$, and if it is an inline formula, you should use the format $a=b$.
                      \(currentLocation)
                      """
}
