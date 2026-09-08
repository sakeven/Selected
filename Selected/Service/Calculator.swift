import Foundation
import MathParser

func calculate(_ equation: String) -> Double? {
    // if equation can pasre as a double number, the equation must be single number but not an equation.
    let d = Double(equation.trimmingCharacters(in: .init(charactersIn: " \n")))
    if d != nil {
        // return nil to avoid displaying the single number.
        return nil
    }
    // it will still return 30 if the equation is somewhat like `(30)`.
    return try? equation.evaluate()
}
