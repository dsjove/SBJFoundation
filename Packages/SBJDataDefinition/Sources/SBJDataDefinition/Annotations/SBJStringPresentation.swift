import Foundation

/// Provides presentation preferences for text; it does not change structural string constraints.
@attached(peer)
public macro SBJStringPresentation(_ style: SBJStringStyle = .singleLine, autocorrect: SBJTextAutocorrection = .automatic, capitalization: SBJTextCapitalization = .automatic) = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJStringPresentationMacro")
