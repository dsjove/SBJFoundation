import Foundation

/// Declares text presentation metadata and length constraints for `@SBJStructure`.
public enum SBJStringStyle: String, Codable, Sendable, Equatable {
    case singleLine
    case multiline
    /// Uses a compact multiline field with an affordance that promotes editing into a sheet.
    /// This is an editor interaction hint; storage, validation, Codable, and future
    /// localization/text-resolution semantics remain those of ordinary text.
    case sheetEdit
}



public enum SBJTextAutocorrection: String, Codable, Sendable, Hashable {
    case automatic
    case enabled
    case disabled
}

public enum SBJTextCapitalization: String, Codable, Sendable, Hashable {
    case automatic
    case never
    case words
    case sentences
    case characters
}

public enum SBJStringTrimming: String, Codable, Sendable, Equatable {
    case none
    case whitespace
    case whitespaceAndNewlines

    func apply(to value: String) -> String {
        switch self {
        case .none:
            value
        case .whitespace:
            value.trimmingCharacters(in: .whitespaces)
        case .whitespaceAndNewlines:
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
