/// Excludes stored instance state from synthesized structural equivalence only.
@attached(peer)
public macro SBJExcludeFromStructuralEquivalence() = #externalMacro(module: "SBJStructureMacros", type: "SBJExcludeMacro")
