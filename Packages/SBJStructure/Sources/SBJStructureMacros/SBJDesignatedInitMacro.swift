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

        let bodySource = initializer.body?.description ?? ""

        let parameters = initializer.signature.parameterClause.parameters.map { parameter -> String in
            let externalName = parameter.firstName.text
            let localName = parameter.secondName?.text ?? externalName
            let propertyName = directlyAssignedProperty(for: localName, bodySource: bodySource) ?? localName
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
        bodySource: String
    ) -> String? {
        // Initializer assignments are often formatted across multiple lines.
        // Restrict the match to a direct self.property = parameter assignment;
        // do not mistake comparisons or expressions for mappings.
        let escaped = NSRegularExpression.escapedPattern(for: parameterName)
        let pattern = #"\bself\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?![=])"#
            + escaped + #"\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: bodySource,
                range: NSRange(bodySource.startIndex..<bodySource.endIndex, in: bodySource)
              ),
              let range = Range(match.range(at: 1), in: bodySource) else {
            return nil
        }
        return String(bodySource[range])
    }
}
