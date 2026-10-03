#if !os(tvOS) && !os(watchOS)
import SwiftUI

private struct SBJEditorIsChangedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SBJEditorHasContentKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

private struct SBJEditorIsInvalidKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SBJEditorValidationStateChangedKey: EnvironmentKey {
    static let defaultValue: @MainActor (Bool) -> Void = { _ in }
}

extension EnvironmentValues {
    var sbjEditorIsChanged: Bool {
        get { self[SBJEditorIsChangedKey.self] }
        set { self[SBJEditorIsChangedKey.self] = newValue }
    }

    var sbjEditorHasContent: Bool? {
        get { self[SBJEditorHasContentKey.self] }
        set { self[SBJEditorHasContentKey.self] = newValue }
    }

    var sbjEditorIsInvalid: Bool {
        get { self[SBJEditorIsInvalidKey.self] }
        set { self[SBJEditorIsInvalidKey.self] = newValue }
    }

    var sbjEditorValidationStateChanged: @MainActor (Bool) -> Void {
        get { self[SBJEditorValidationStateChangedKey.self] }
        set { self[SBJEditorValidationStateChangedKey.self] = newValue }
    }
}


struct SBJEditorOriginalValue {
    let valueType: Any.Type
    private let storage: Any

    init<Value>(_ value: Value) {
        valueType = Value.self
        storage = value
    }

    func value<Value>(as type: Value.Type = Value.self) -> Value {
        precondition(
            ObjectIdentifier(valueType) == ObjectIdentifier(type),
            "SBJEditorOriginalValue type mismatch: stored \(String(describing: valueType)), requested \(String(describing: type))"
        )
        guard let value = storage as? Value else {
            preconditionFailure(
                "SBJEditorOriginalValue could not recover \(String(describing: type)) from stored value"
            )
        }
        return value
    }
}


enum SBJEditorStatusKind {
    case changed
    case empty

    var image: ImageReference {
        switch self {
        case .changed:
            return SBJSemanticImageReference.changed
        case .empty:
            return SBJSemanticImageReference.empty
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .changed:
            return "Changed from original value"
        case .empty:
            return "No content"
        }
    }

    var shortLabel: String {
        switch self {
        case .changed:
            return "Changed"
        case .empty:
            return "Empty"
        }
    }
}

/// Shared status glyph used both by editor rows and by the matching search
/// filters.  Keeping one glyph per status makes the row markers self-teaching:
/// the symbol a user sees beside a value is the same symbol used to filter for
/// that state in the search bar.
struct SBJEditorStatusSymbol: View {
    let kind: SBJEditorStatusKind

    var body: some View {
        Image(kind.image)
            .font(.caption.weight(.semibold))
            .fixedSize()
            .accessibilityLabel(kind.accessibilityLabel)
    }
}

struct SBJEditorChangeIndicator: View {
    @Environment(\.sbjEditorIsChanged) private var isChanged

    var body: some View {
        if isChanged {
            SBJEditorStatusSymbol(kind: .changed)
                .foregroundStyle(SBJUIAppearance.changedColor)
        }
    }
}

/// Marker for editor values whose domain-level `hasContent` is false.
/// Values that do not implement `HasContentCheckable` have no marker.
struct SBJEditorEmptyContentIndicator: View {
    @Environment(\.sbjEditorHasContent) private var hasContent

    var body: some View {
        if hasContent == false {
            SBJEditorStatusSymbol(kind: .empty)
                .foregroundStyle(SBJUIAppearance.emptyColor)
        }
    }
}
#endif
