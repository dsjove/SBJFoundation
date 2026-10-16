import Foundation

public enum SBJHexError: Error, Equatable, LocalizedError {
    case invalidCharacter(Character)
    case incompleteByte

    public var errorDescription: String? {
        switch self {
        case .invalidCharacter(let character):
            return "Invalid hexadecimal character '\(character)'."
        case .incompleteByte:
            return "Hexadecimal data must contain complete bytes."
        }
    }
}

public extension String {
    /// Parses hexadecimal bytes while ignoring common visual separators and whitespace.
    /// Odd nibble counts are rejected rather than silently repaired.
    func sbjHexData() throws -> Data {
        var digits = ""
        digits.reserveCapacity(count)
        let ignored = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".:_-"))
        for scalar in unicodeScalars {
            if ignored.contains(scalar) { continue }
            guard CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains(scalar) else {
                throw SBJHexError.invalidCharacter(Character(String(scalar)))
            }
            digits.unicodeScalars.append(scalar)
        }
        guard digits.count.isMultiple(of: 2) else { throw SBJHexError.incompleteByte }

        var result = Data()
        result.reserveCapacity(digits.count / 2)
        var index = digits.startIndex
        while index < digits.endIndex {
            let next = digits.index(index, offsetBy: 2)
            let byte = UInt8(digits[index..<next], radix: 16)!
            result.append(byte)
            index = next
        }
        return result
    }

    /// Compatibility convenience for callers that prefer optional parsing.
    func sbjHexToData() -> Data? {
        try? sbjHexData()
    }
}
