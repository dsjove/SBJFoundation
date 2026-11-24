import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Synthesizes static property-info lookup from `fooInfo` members in an extension.
/// The generated extension lookup falls back to the primary type's `_nomenclature(for:)`.
public struct SBJNomenclatureMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let extensionDecl = declaration.as(ExtensionDeclSyntax.self) else {
            throw Error.onlyExtensions
        }

        var names: [String] = []
        var hasCustomPublicLookup = false
        for member in extensionDecl.memberBlock.members {
            if let function = member.decl.as(FunctionDeclSyntax.self),
               function.name.text == "propertyNomenclature",
               function.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) {
                hasCustomPublicLookup = true
            }
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) else {
                continue
            }
            for binding in variable.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                      identifier.hasSuffix("Nomenclature"), identifier.count > 12 else {
                    continue
                }
                names.append(String(identifier.dropLast(12)))
            }
        }

        // Enum cases cannot be key-path targets. Reuse the same `nameNomenclature`
        // convention but synthesize a case-name lookup instead.
        let isEnumCases = node.attributeName.trimmedDescription == "SBJNomenclatureEnum"
        if isEnumCases {
            let checks = names.map { name in
                "case \"\(name)\": return Self.\(name)Nomenclature"
            }.joined(separator: "\n            ")
            return [DeclSyntax(stringLiteral: """
            public static func sbjCaseNomenclature(for caseName: String) -> SBJNomenclature? {
                switch caseName {
                \(checks)
                default: return nil
                }
            }
            """)]
        }

        // An extension of a class cannot use covariant Self in a KeyPath parameter.
        let typeName = extensionDecl.extendedType.trimmedDescription
        let checks = names.enumerated().map { index, name in
            "if keyPath == \\\(typeName).\(name) {\n\(index == 0 ? "        " : "    ")return Self.\(name)Nomenclature\n}"
        }.joined(separator: "\n")

        let fallback = "return Self._nomenclature(for: keyPath)"

        // Use direct key-path equality rather than switching on AnyKeyPath.
        // The latter can crash SILGen for class extensions in Swift 6.4.
        var members: [DeclSyntax] = [DeclSyntax(stringLiteral: """
        public static func _extensionNomenclature<Value>(for keyPath: KeyPath<\(typeName), Value>) -> SBJNomenclature? {
            \(checks)
            \(fallback)
        }
        """)]
        if !hasCustomPublicLookup {
            members.append(DeclSyntax(stringLiteral: """
            public static func propertyNomenclature<Value>(for keyPath: KeyPath<\(typeName), Value>) -> SBJNomenclature? {
                SBJNomenclatureResolver.resolve(_extensionNomenclature(for: keyPath), for: Value.self)
            }
            """))
        }
        return members
    }

    private enum Error: Swift.Error {
        case onlyExtensions
    }
}
