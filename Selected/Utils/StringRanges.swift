import Foundation

extension StringProtocol {
    func index<S: StringProtocol>(of string: S, options: String.CompareOptions = []) -> Index? {
        range(of: string, options: options)?.lowerBound
    }
    func endIndex<S: StringProtocol>(of string: S) -> Index? {
        let indeics = ranges(of: string).map(\.lowerBound)
        if indeics.count > 0 {
            return indeics[indeics.count-1]
        }
        return nil
    }
}
