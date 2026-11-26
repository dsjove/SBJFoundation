import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SBJStructureMacroSupport

/// Generates structural metadata without editor-specific declarations.
public struct SBJStructureMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        _ = try atomicArgument(node)
        return try SBJStructureGeneration.members(of: declaration, in: context, layers: [])
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        var extensions = try SBJStructureGeneration.extensions(of: declaration, type: type, layers: [])
        if try atomicArgument(node), !extensions.isEmpty {
            let atomic: DeclSyntax = """
            extension \(type.trimmed): SBJAtomicStructuralValue {}
            """
            extensions.append(atomic.cast(ExtensionDeclSyntax.self))
        }
        return extensions
    }
    private static func atomicArgument(_ node: AttributeSyntax) throws -> Bool {
        guard case .argumentList(let arguments) = node.arguments,
              let argument = arguments.first(where: { $0.label?.text == "atomic" }) else { return false }
        guard let literal = argument.expression.as(BooleanLiteralExprSyntax.self) else {
            throw AtomicArgumentError.literalRequired
        }
        return literal.literal.text == "true"
    }

    private enum AtomicArgumentError: Error, CustomStringConvertible {
        case literalRequired
        var description: String { "SBJStructure atomic must be a Boolean literal" }
    }
}
