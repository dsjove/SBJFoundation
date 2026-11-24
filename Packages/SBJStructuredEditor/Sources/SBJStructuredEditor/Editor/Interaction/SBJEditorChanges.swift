import SBJLocalization
import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import SwiftUI

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

    var nomenclature: SBJNomenclature {
        switch self {
        case .changed: SBJStructuredEditorNomenclature.changed
        case .empty: SBJStructuredEditorNomenclature.empty
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
        Image(symbol: kind.nomenclature.symbol!)
            .font(.caption.weight(.semibold))
            .fixedSize()
            .accessibility(kind.nomenclature)
    }
}

struct SBJEditorChangeIndicator: View {
    let isChanged: Bool

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
    let hasContent: Bool?

    var body: some View {
        if hasContent == false {
            SBJEditorStatusSymbol(kind: .empty)
                .foregroundStyle(SBJUIAppearance.emptyColor)
        }
    }
}
#endif
