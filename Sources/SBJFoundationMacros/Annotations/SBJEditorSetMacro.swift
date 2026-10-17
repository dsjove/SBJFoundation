import SwiftSyntax
import SwiftSyntaxMacros

/// Marker interpreted by SBJStructureMacro; emits no peer declarations.
public struct SBJEditorSetMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
