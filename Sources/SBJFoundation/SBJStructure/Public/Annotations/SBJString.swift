import Foundation

/// Declares text presentation metadata and length constraints for `@SBJStructure`.
public enum SBJStringStyle: Sendable, Equatable {
    case singleLine
    case multiline
    /// Uses a compact multiline field with an affordance that promotes editing into a sheet.
    /// This is an editor interaction hint; storage, validation, Codable, and future
    /// localization/text-resolution semantics remain those of ordinary text.
    case sheetEdit
}



public enum SBJTextAutocorrection: Sendable, Equatable {
    case automatic
    case enabled
    case disabled
}

public enum SBJTextCapitalization: Sendable, Equatable {
    case automatic
    case never
    case words
    case sentences
    case characters
}

public enum SBJStringTrimming: Sendable, Equatable {
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

/// Adds String presentation and/or length information beyond the Swift type.
/// Unannotated `String` values already participate and default to `.singleLine`.
/// Length constraints are emitted into the containing type's generated `_invariant`.
@attached(peer)
public macro SBJString(
    _ style: SBJStringStyle = .singleLine,
    minLength: Int? = nil,
    maxLength: Int? = nil,
    trimming: SBJStringTrimming = .none,
    autocorrect: SBJTextAutocorrection = .automatic,
    capitalization: SBJTextCapitalization = .automatic
) = #externalMacro(module: "SBJFoundationMacros", type: "SBJStringMacro")
