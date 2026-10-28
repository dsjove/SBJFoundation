import SwiftSyntax
import SwiftSyntaxMacros

/// Metadata-only annotation consumed by SBJStructure's generation layer.
public struct SBJUnitValuePresentationMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
