#if !os(tvOS) && !os(watchOS)
import SwiftUI
import SBJFileResources
import SBJUIVocabulary
import SBJUnits

public extension SBJBundledContentReference {
    static var structuredEditorCore: SBJBundledContentReference {
        .help("Structure Editor", resourceName: "SBJStructureEditorCore", bundle: .module)
    }
}

/// The reflected editor content without search controls or a scrolling container.
///
/// The host owns layout and scrolling. Pair this with ``SBJEditorSearchView``
/// when the stock search/filter UI is desired.
public struct SBJEditorView<Value: SBJSwiftUIEditable>: View {
    @Binding private var value: Value
    private let presentationModel: SBJEditorPresentationModel
    private let registry: SBJEditorRegistry
    private let documentID: String?
    private let options: SBJEditorOptions
    @State private var originalValue: Value

    /// Pass a stable logical document ID when this view can switch documents
    /// without being removed from the SwiftUI hierarchy. Changing it resets
    /// the baseline used by changed-only presentation; ordinary edits do not.
    public init(
        value: Binding<Value>,
        presentationModel: SBJEditorPresentationModel,
        registry: SBJEditorRegistry = .init(),
        documentID: String? = nil,
        options: SBJEditorOptions = .init()
    ) {
        self._value = value
        self.documentID = documentID
        self.options = options
        self.presentationModel = presentationModel
        self.registry = registry
        self._originalValue = State(initialValue: value.wrappedValue.sbjCodableCopy())
    }

    /// Project only the exposed nodes; closed branches never construct child
    /// descriptors or SwiftUI views. The host owns the scrolling container.
    private var editorRows: [SBJEditorTraversalNode] {
        SBJEditorPerformanceDiagnostics.measure("Editor Row Projection") {
            sbjEditorRows(
                roots: Value._sbjBoundRootNodes(
                    binding: $value,
                    originalValue: originalValue,
                    registry: registry
                ),
                presentationModel: presentationModel
            )
        }
    }

    public var body: some View {
        let rows = editorRows
        return LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 8) {
                    if let rendered = row.renderedRow() {
                        rendered
                            .sbjEditorNavigationAnchor(for: row.context.navigationPath)
                    }
                    ForEach(Array(row.endDividerLevels.enumerated()), id: \.offset) { entry in
                        SBJEditorGroupEnd(indentLevel: entry.element)
                    }
                }
                .id(row.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(presentationModel)
        .onChange(of: documentID) { _, _ in
            // A different logical document starts a new comparison baseline.
            // Edits within one document must not reset this snapshot.
            originalValue = value.sbjCodableCopy()
        }
        .transaction { transaction in
            if !options.animationsEnabled {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }
}



/// Reusable default composition for values annotated with ``SBJStructure()``.
///
/// This convenience view keeps search and editor content together and uses
/// ``SBJEditorScrollView`` so issue navigation can reveal and scroll to a field.
/// Clients that need independent placement or a custom scrolling policy should
/// use ``SBJEditorSearchView`` and ``SBJEditorView`` directly.
public struct SBJCodableEditorCore<Value: SBJSwiftUIEditable>: View {
    @Binding private var value: Value
    private let registry: SBJEditorRegistry
    private let options: SBJEditorOptions
    @State private var presentationModel = SBJEditorPresentationModel()

    public init(
        value: Binding<Value>,
        registry: SBJEditorRegistry = .init(),
        options: SBJEditorOptions = .init()
    ) {
        self._value = value
        self.registry = registry
        self.options = options
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SBJEditorSearchView(value: value, presentationModel: presentationModel, registry: registry)
            SBJEditorScrollView(presentationModel: presentationModel) {
                SBJEditorView(value: $value, presentationModel: presentationModel, registry: registry, options: options)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Compatibility wrapper around ``SBJCodableEditorCore``.
public struct SBJCodableEditor<Value: SBJSwiftUIEditable>: View {
    @Binding private var value: Value
    private let registry: SBJEditorRegistry
    private let options: SBJEditorOptions

    public init(
        _ title: String? = nil,
        value: Binding<Value>,
        registry: SBJEditorRegistry = .init(),
        options: SBJEditorOptions = .init()
    ) {
        self._value = value
        self.registry = registry
        self.options = options
    }

    public var body: some View {
        SBJCodableEditorCore(value: $value, registry: registry, options: options)
    }
}
#endif
