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

public extension Data {
    var sbjHexDescription: String {
        sbjHexFormat(bytesPerRow: 16)
    }

    /// Formats bytes as uppercase, space-separated hexadecimal suitable for editing.
    func sbjHexFormat(bytesPerRow: Int = 16, indent: String = "") -> String {
        guard !isEmpty else { return "" }
        let rowSize = Swift.max(1, bytesPerRow)
        var rows: [String] = []
        rows.reserveCapacity((count + rowSize - 1) / rowSize)
        for rowStart in stride(from: 0, to: count, by: rowSize) {
            let rowEnd = Swift.min(rowStart + rowSize, count)
            let row = self[rowStart..<rowEnd]
                .map { String(format: "%02X", $0) }
                .joined(separator: " ")
            rows.append(indent + row)
        }
        return rows.joined(separator: "\n")
    }
}
