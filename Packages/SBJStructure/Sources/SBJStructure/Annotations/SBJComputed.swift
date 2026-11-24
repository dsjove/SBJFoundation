import Foundation

/// Includes a computed property in semantic discovery without including it in
/// coding, content checks, structural equality, or structural mutation.
/// Nomenclature still comes from `propertyNomenclature(for:)` and `nameNomenclature`.
/// `showInEditor` is opt-in because many calculated values are not useful rows.
@attached(peer)
public macro SBJComputed(showInEditor: Bool = false) = #externalMacro(
    module: "SBJStructureMacros", type: "SBJComputedMacro"
)
