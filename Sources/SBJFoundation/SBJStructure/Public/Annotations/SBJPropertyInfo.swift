/// Generates `static _extensionPropertyInfo(for:)` and the default `static propertyInfo(for:)` using static `fooInfo` declarations
/// in the annotated extension. For declarations on the primary type,
/// `@SBJStructure` already performs discovery without this annotation.
/// Supports stored `static let` and computed `static var { get }` metadata.
@attached(member, names: named(_extensionPropertyInfo), named(propertyInfo))
public macro SBJPropertyInfo() = #externalMacro(
    module: "SBJFoundationMacros", type: "SBJPropertyInfoMacro"
)
