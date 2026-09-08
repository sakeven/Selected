import Testing
@testable import Selected

struct CalculatorTests {
    @Test(arguments: ["42", " 42\n", "-2", "3.14", "1e3"])
    func standaloneNumbersDoNotShowCalculator(text: String) {
        #expect(calculate(text) == nil)
    }

    @Test func expressionsAndParenthesizedNumbersStillEvaluate() {
        #expect(calculate("1 + 2 * 3") == 7)
        #expect(calculate("(30)") == 30)
        #expect(calculate("(8 - 2) / 3") == 2)
        #expect(calculate("not an equation") == nil)
    }
}
