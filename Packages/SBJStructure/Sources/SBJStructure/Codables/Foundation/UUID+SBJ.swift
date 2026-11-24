import Foundation

public extension UUID {
    /// The all-zero UUID value, useful for sentinel checks and model invariants.
    static let sbjZero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    /// Whether this UUID is the all-zero UUID.
    var sbjIsZero: Bool { self == .sbjZero }
}

public extension String {
    /// Parses a UUID from canonical, compact, or brace-wrapped text.
    ///
    /// Compact 32-character UUIDs are normalized by inserting the canonical
    /// hyphens before parsing.
    var sbjUUID: UUID? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
        if let direct = UUID(uuidString: trimmed) { return direct }

        let compact = trimmed.replacingOccurrences(of: "-", with: "")
        guard compact.count == 32 else { return nil }
        let positions = Set([8, 12, 16, 20])
        var canonical = ""
        canonical.reserveCapacity(36)
        for (index, character) in compact.enumerated() {
            if positions.contains(index) { canonical.append("-") }
            canonical.append(character)
        }
        return UUID(uuidString: canonical)
    }
}
