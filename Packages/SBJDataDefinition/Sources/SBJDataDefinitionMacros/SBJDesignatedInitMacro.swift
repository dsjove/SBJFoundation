import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Generates the initializer-label metadata consumed by `SBJSwiftEncoder`.
public struct SBJDesignatedInitMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let initializer = declaration.as(InitializerDeclSyntax.self) else {
            return []
        }

        let bodyLines = initializer.body?.description
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? []

        let parameters = initializer.signature.parameterClause.parameters.map { parameter -> String in
            let externalName = parameter.firstName.text
            let localName = parameter.secondName?.text ?? externalName
            let propertyName = directlyAssignedProperty(for: localName, bodyLines: bodyLines) ?? localName
            let label = externalName == "_" ? "nil" : "\"\(externalName)\""
            if let defaultValue = parameter.defaultValue?.value.description {
                let defaultExpression = String(
                    reflecting: defaultValue.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                return ".init(propertyName: \"\(propertyName)\", label: \(label), defaultExpression: \(defaultExpression))"
            }
            return ".init(propertyName: \"\(propertyName)\", label: \(label))"
        }.joined(separator: ",\n")

        let declaration: DeclSyntax = """
        public static var sbjSwiftInitializerParameters: [SBJSwiftInitializerParameter] {
            [
                \(raw: parameters)
            ]
        }
        """
        return [declaration]
    }

    private static func directlyAssignedProperty(
        for parameterName: String,
        bodyLines: [String]
    ) -> String? {
        for line in bodyLines where line.hasPrefix("self.") {
            let pieces = line.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard pieces.count == 2, pieces[1] == parameterName else { continue }
            let lhs = pieces[0]
            guard lhs.hasPrefix("self.") else { continue }
            return String(lhs.dropFirst("self.".count))
        }
        return nil
    }
}
