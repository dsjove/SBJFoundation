import SwiftSyntax
import SwiftSyntaxMacros
import SBJStructureMacroSupport

/// Editor umbrella annotation: structural generation plus editor integration.
public struct SBJEditableMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try SBJStructureGeneration.members(of: declaration, in: context, includingEditor: true)
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        try SBJStructureGeneration.extensions(of: declaration, type: type, includingEditor: true)
    }
}

