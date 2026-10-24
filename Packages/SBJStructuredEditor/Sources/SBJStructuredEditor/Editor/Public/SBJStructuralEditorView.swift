import SBJDataDefinition
#if !os(tvOS) && !os(watchOS)
/// Historical structural-root spelling. Both public names use the same
/// metadata-driven editor implementation.
public typealias SBJStructuralEditorView<Value: SBJMutableStructure> = SBJEditorView<Value>
#endif
