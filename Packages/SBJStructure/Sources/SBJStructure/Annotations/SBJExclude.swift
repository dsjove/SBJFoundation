/// Omits a declaration from structural discovery; stored state still participates in equivalence.
@attached(peer)
public macro SBJExclude() = #externalMacro(module: "SBJStructureMacros", type: "SBJExcludeMacro")
