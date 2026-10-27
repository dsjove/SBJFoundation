import Foundation

public extension Encodable {
    /// Compares two encodable values using stable JSON encoding.
    ///
    /// This is primarily useful for model/UI change tracking. If either value
    /// cannot be encoded, the comparison falls back to textual descriptions.
    func sbjEncodedIsDifferent(from other: Self) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let lhs = try? encoder.encode(self),
              let rhs = try? encoder.encode(other) else {
            return String(describing: self) != String(describing: other)
        }
        return lhs != rhs
    }
}

public extension Decodable where Self: Encodable {
    /// Creates an independent Codable copy by encoding and decoding the value.
    /// Returns the original value if the round trip cannot be completed.
    func sbjCodableCopy() -> Self {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        guard let data = try? encoder.encode(self),
              let copy = try? decoder.decode(Self.self, from: data) else {
            return self
        }
        return copy
    }
}
