import Foundation

public extension String {
    /// Case-insensitive, surrounding-whitespace-insensitive equality.
    func isEquivalent(to other: String?) -> Bool {
        guard let other else { return false }
        return trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(other.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

}
