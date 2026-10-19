import SwiftUI
import SBJDataDefinition
import SBJLocalization

/// Searchable single-selection presentation that supports both required and optional selections.
///
/// The filled dot marks the value that was selected when the view was presented; the checkmark
/// marks the current pending selection.
public struct SBJSelectionView<Element: Identifiable, Label: View>: View {
    @Environment(\.dismiss) private var dismiss

    private let title: String
    private let noun: String
    private let elements: (String) -> [Element]?
    private let enabled: (Element) -> Bool
    private let onSelect: (Element?) -> Void
    private let allowsNilSelection: Bool
    private let label: (Element) -> Label
    private let initialID: Element.ID?

    @State private var selected: Element?
    @State private var searchText = ""

    public init(
        title: String? = nil,
        noun: String,
        elements: @escaping (String) -> [Element]?,
        enabled: @escaping (Element) -> Bool = { _ in true },
        selection: Binding<Element?>,
        @ViewBuilder label: @escaping (Element) -> Label
    ) {
        self.init(
            title: title,
            noun: noun,
            elements: elements,
            enabled: enabled,
            initial: selection.wrappedValue,
            allowsNilSelection: true,
            onSelect: { selection.wrappedValue = $0 },
            label: label
        )
    }

    public init(
        title: String? = nil,
        noun: String,
        elements: @escaping (String) -> [Element]?,
        enabled: @escaping (Element) -> Bool = { _ in true },
        selection: Binding<Element>,
        @ViewBuilder label: @escaping (Element) -> Label
    ) {
        self.init(
            title: title,
            noun: noun,
            elements: elements,
            enabled: enabled,
            initial: selection.wrappedValue,
            allowsNilSelection: false,
            onSelect: { value in
                if let value { selection.wrappedValue = value }
            },
            label: label
        )
    }

    public init(
        title: String? = nil,
        noun: String,
        elements: @escaping (String) -> [Element]?,
        enabled: @escaping (Element) -> Bool = { _ in true },
        initial selection: Element? = nil,
        onSelect: @escaping (Element) -> Void,
        @ViewBuilder label: @escaping (Element) -> Label
    ) {
        self.init(
            title: title,
            noun: noun,
            elements: elements,
            enabled: enabled,
            initial: selection,
            allowsNilSelection: false,
            onSelect: { value in
                if let value { onSelect(value) }
            },
            label: label
        )
    }

    public init(
        title: String? = nil,
        noun: String,
        elements: @escaping (String) -> [Element]?,
        enabled: @escaping (Element) -> Bool = { _ in true },
        initial selection: Element? = nil,
        allowsNilSelection: Bool = true,
        onSelect: @escaping (Element?) -> Void,
        @ViewBuilder label: @escaping (Element) -> Label
    ) {
        self.title = title ?? "Select a \(noun.capitalized)"
        self.noun = noun
        self.elements = elements
        self.enabled = enabled
        self.onSelect = onSelect
        self.allowsNilSelection = allowsNilSelection
        self.label = label
        self._selected = State(initialValue: selection)
        self.initialID = selection?.id
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                SearchField(searching: $searchText)
                    .padding(.horizontal)

                if let elements = elements(searchText) {
                    if elements.isEmpty {
                        Spacer()
                        Text("No \(noun) found.")
                        Spacer()
                    } else {
                        List {
                            ForEach(elements) { element in
                                selectionRow(for: element)
                            }
                        }
                    }
                } else {
                    Spacer()
                    Text("No \(noun) available.")
                    Spacer()
                }
            }
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        onSelect(selected)
                        dismiss()
                    }
                    .disabled(!allowsNilSelection && selected == nil)
                }
            }
        }
    }

    @ViewBuilder
    private func selectionRow(for element: Element) -> some View {
        let isEnabled = enabled(element)
        let isSelected = selected?.id == element.id

        Button {
            guard isEnabled else { return }
            selected = isSelected && allowsNilSelection ? nil : element
        } label: {
            HStack {
                if element.id == initialID {
                    Image(symbol: SBJSymbology.originalSelection)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
                label(element)
                Spacer()
                if isSelected {
                    Image(symbol: SBJSymbology.selected)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .foregroundStyle(isEnabled ? .primary : .secondary)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}
