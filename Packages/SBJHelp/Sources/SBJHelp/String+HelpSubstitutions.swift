import Foundation

extension String {
    /// Applies a set of literal replacements in sequence.
    func replacingOccurrences(using replacements: [String: String]) -> String {
        replacements.reduce(self) { result, replacement in
            result.replacingOccurrences(of: replacement.key, with: replacement.value)
        }
    }
}
