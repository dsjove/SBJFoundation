import Foundation

/// Human-readable type notation for report output only. Reflected types and
/// catalog identities retain their original, fully qualified spelling.
public enum SBJDefinitionTypeDisplay {
    public static func format(_ reflectedName: String) -> String {
        reflectedName.replacingOccurrences(of: "Swift.", with: "")
    }
}
