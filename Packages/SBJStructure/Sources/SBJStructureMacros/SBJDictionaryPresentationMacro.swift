import SwiftSyntax
import SwiftSyntaxMacros

/// Metadata-only marker interpreted by SBJStructure.
public struct SBJDictionaryPresentationMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
