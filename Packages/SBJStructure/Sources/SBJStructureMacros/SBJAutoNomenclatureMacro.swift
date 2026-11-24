import SwiftSyntax
import SwiftSyntaxMacros

/// Resolves the display title from the enclosing `nameNomenclature` declaration
/// at macro expansion time. The resulting value contains an ordinary String:
/// there is no runtime naming lookup and direct property access is resolved.
public struct SBJAutoNomenclatureMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let declaration = context.lexicalContext
            .compactMap({ $0.as(VariableDeclSyntax.self) }).first,
              let name = declaration.bindings.first?.pattern
                .as(IdentifierPatternSyntax.self)?.identifier.text,
              name.hasSuffix("Nomenclature"), name.count > "Nomenclature".count else {
            throw ExpansionError.requiresNomenclatureDeclaration
        }
        let sourceName = String(name.dropLast("Nomenclature".count))
        let title = readableTitle(sourceName)
        let literal = String(reflecting: title)
        // A LabeledExprSyntax includes its separator in trimmedDescription.
        // Strip each argument's trailing comma before adding our own separators.
        let arguments = node.arguments
            .map { $0.with(\.trailingComma, nil).trimmedDescription }
            .joined(separator: ", ")
        let suffix = arguments.isEmpty ? "" : ", " + arguments
        return ExprSyntax(stringLiteral: "SBJNomenclature(title: \(literal)\(suffix))")
    }

    private static func readableTitle(_ name: String) -> String {
        let characters = Array(name)
        var result = ""
        for index in characters.indices {
            let character = characters[index]
            if character == "_" {
                if result.last != " " { result.append(" ") }
                continue
            }
            if index > characters.startIndex {
                let previous = characters[index - 1]
                let next = index + 1 < characters.endIndex ? characters[index + 1] : nil
                let newWord = character.isUppercase && previous != "_" && (
                    previous.isLowercase || previous.isNumber ||
                    (previous.isUppercase && next?.isLowercase == true)
                )
                if newWord && result.last != " " { result.append(" ") }
            }
            result.append(character)
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    private enum ExpansionError: Error {
        case requiresNomenclatureDeclaration
    }
}
