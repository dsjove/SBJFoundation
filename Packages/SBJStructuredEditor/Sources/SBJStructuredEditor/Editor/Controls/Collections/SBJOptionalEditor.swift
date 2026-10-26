import SBJDataDefinition
import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

struct SBJOptionalEditor<Wrapped: Codable>: View {
    private var sbjFormatting: SBJEditorFormattingOptions { presentationModel.formattingOptions }
    let label: String
    @Binding var value: Wrapped?
    let originalValue: Wrapped??
    let registry: SBJEditorRegistry
    let textStyle: SBJStringStyle?
    let integerRange: ClosedRange<Int>?
    let numberRange: ClosedRange<Double>?
    let dateRange: ClosedRange<Date>?
    let colorSupportsAlpha: Bool
    let unitEditor: SBJUnitValueEditorMode
    let unitSystem: MeasurementSystem?
    let collectionReorderable: Bool
    let collectionItemTitleKey: String?
    let collectionItemIdentifierKey: String?
    let itemActions: SBJEditorItemActions?
    let focusRequest: SBJEditorFocusRequest?
    let context: SBJEditTraversalContext
    @Environment(SBJEditorPresentationModel.self) private var presentationModel
    @State private var pendingFocus: SBJEditorFocusRequest?
    private var searchCriteria: SBJStructuralSearchCriteria { context.branch.searchCriteria }
    private var navigationTarget: SBJEditorNavigationTarget? { presentationModel.navigationTarget }
    private var hasContent: Bool? { context.branch.status.hasContent }

    /// Optional rows reserve the disclosure lane only when the populated value
    /// actually uses a disclosure header.  In particular, a one-field structured
    /// value is flattened, so its nil state must not reserve a disclosure column
    /// that disappears as soon as the value is created.
    private var wrappedNeedsDisclosure: Bool {
        if let structural = Wrapped.self as? any SBJMutableStructure.Type {
            return structural._sbjStructuralFieldCount > 1
        }
        return false
    }

    private var navigationIsExpanded: Bool {
        presentationModel.navigationIncludes(context)
    }

    private var disclosureBinding: Binding<Bool> {
        presentationModel.disclosureBinding(for: context)
    }

    var body: some View {
        Group {
            if searchCriteria.showEmptyContentOnly && hasContent == false && navigationIsExpanded == false {
            SBJEditorRow(
                context: context,

                optionalControl: value == nil ? AnyView(setButton) : AnyView(clearButton),
                trailingActions: itemActions?.trailingView,
                    infoAction: itemActions?.infoLaneView
            ) {
                HStack(spacing: 8) {
                    SBJEditorFieldName(text: label, isUnknown: false)
                        .fontWeight((Wrapped.self is any SBJMutableStructure.Type) ? .semibold : .regular)
                    Spacer(minLength: 0)
                }
            }
        } else if let currentValue = value {
            // A child editor can be evaluated once more in the same SwiftUI
            // update transaction after this optional is cleared. Do not hand
            // it SwiftUI's failable optional Binding, whose getter becomes
            // invalid as soon as the source turns nil. Keep the last value as
            // a read-only fallback for that transient lifetime and ignore stale
            // writes after the optional has been removed.
            let unwrapped = Binding<Wrapped>(
                get: { value ?? currentValue },
                set: { newValue in
                    guard value != nil else { return }
                    value = newValue
                }
            )
            if let structural = Wrapped.self as? any SBJMutableStructure.Type,
                      structural._sbjStructuralFieldCount > 1 {
                SBJEditorDisclosureHeader(
                    label,
                    context: context,
                    isExpanded: disclosureBinding,
                    leadingActions: AnyView(EmptyView()),
                    optionalControl: AnyView(clearButton),
                    trailingActions: itemActions?.trailingView ?? AnyView(EmptyView()),
                        infoAction: itemActions?.infoLaneView
                )
            } else {
                SBJEditorRow(
                    context: context,

                    optionalControl: AnyView(clearButton),
                    trailingActions: itemActions?.trailingView,
                    infoAction: itemActions?.infoLaneView
                ) {
                    SBJValueEditor.makeView(
                        label: label,
                        value: unwrapped,
                        originalValue: originalWrapped.map { SBJEditorOriginalValue($0) },
                        registry: registry,
                        textStyle: textStyle,
                        integerRange: integerRange,
                        numberRange: numberRange,
                        dateRange: dateRange,
                        colorSupportsAlpha: colorSupportsAlpha,
                        unitEditor: unitEditor,
                        unitSystem: unitSystem,
                        collectionReorderable: collectionReorderable,
                        collectionItemTitleKey: collectionItemTitleKey,
                        focusRequest: pendingFocus ?? focusRequest,
                        context: context.descended().withBranch(context.branch.child.withPlacement(.contentOnly))
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            SBJEditorRow(
                context: context,
                disclosureControl: wrappedNeedsDisclosure ? AnyView(Color.clear) : nil,

                optionalControl: AnyView(setButton),
                trailingActions: itemActions?.trailingView,
                    infoAction: itemActions?.infoLaneView
            ) {
                HStack(spacing: 8) {
                    SBJEditorFieldName(text: label, isUnknown: false)
                        .fontWeight((Wrapped.self is any SBJMutableStructure.Type) ? .semibold : .regular)
                    Spacer(minLength: 0)
                }
            }
        }
        }
    }

    private var originalWrapped: Wrapped? {
        guard let originalValue else { return nil }
        return originalValue
    }

    private var clearButton: some View {
        SBJSymbolButton(
            SBJStructuredEditorSymbology.clearOptional,
            accessibilityLabel: "Clear \(label)",
            accessibilityHint: "Removes the current optional value"
        ) {
            value = nil
            pendingFocus = nil
        }
        .frame(minHeight: sbjFormatting.firstLineMinimumHeight, alignment: .center)
    }

    private var setButton: some View {
        SBJSymbolButton(
            SBJStructuredEditorSymbology.setOptional,
            accessibilityLabel: "Set \(label)",
            accessibilityHint: "Creates a value and moves focus into the new field"
        ) {
            value = registry.create(Wrapped.self)
            if value != nil {
                presentationModel.open(context.itemIdentifier)
                pendingFocus = SBJEditorFocusRequest()
            }
        }
        .disabled(registry.create(Wrapped.self) == nil)
        .frame(minHeight: sbjFormatting.firstLineMinimumHeight, alignment: .center)
    }
}
#endif
