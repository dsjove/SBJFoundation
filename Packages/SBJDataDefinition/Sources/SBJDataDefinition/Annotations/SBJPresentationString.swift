import Foundation

/// Provides presentation preferences for text; it does not change structural string constraints.
@attached(peer)
public macro SBJPresentationString(_ style: SBJStringStyle = .singleLine, autocorrect: SBJTextAutocorrection = .automatic, capitalization: SBJTextCapitalization = .automatic) = #externalMacro(module: "SBJDataDefinitionMacros", type: "SBJPresentationStringMacro")
