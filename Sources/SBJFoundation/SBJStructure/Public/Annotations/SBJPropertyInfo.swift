import SBJLocalization
/// Synthesizes property metadata lookup from `propertyNameInfo` members in a
/// metadata extension. For enum metadata, use `@SBJPropertyInfoEnum`
/// on the extension and `static let caseNameInfo = SBJPropertyInfo(...)` members.
/// No annotations are needed on individual enum cases.
///
/// The extension marker is required because an attached macro cannot inspect
/// members of other extensions when expanding the original type.
@attached(member, names: named(_extensionPropertyInfo), named(propertyInfo), named(sbjCaseInfo))
public macro SBJPropertyInfo(fallbackToStructure: Bool = true) = #externalMacro(
    module: "SBJFoundationMacros", type: "SBJPropertyInfoMacro"
)

/// Synthesizes enum-case metadata lookup from `caseNameInfo` static members
/// on an extension. Case declarations remain free of metadata annotations.
///
/// A distinct extension marker is needed because an extension macro cannot
/// determine whether the extended type is an enum from extension syntax alone.
@attached(member, names: named(sbjCaseInfo))
public macro SBJPropertyInfoEnum() = #externalMacro(
    module: "SBJFoundationMacros", type: "SBJPropertyInfoMacro"
)
