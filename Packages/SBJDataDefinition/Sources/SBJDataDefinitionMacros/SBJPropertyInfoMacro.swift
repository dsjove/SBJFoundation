import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Synthesizes static property-info lookup from `fooInfo` members in an extension.
/// The generated extension lookup falls back to the primary type's `_propertyInfo(for:)`.
public struct SBJPropertyInfoMacro: MemberMacro {
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
               function.name.text == "propertyInfo",
               function.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) {
                hasCustomPublicLookup = true
            }
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) else {
                continue
            }
            for binding in variable.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                      identifier.hasSuffix("Info"), identifier.count > 4 else {
                    continue
                }
                names.append(String(identifier.dropLast(4)))
            }
        }

        // Enum cases cannot be key-path targets. Reuse the same `nameInfo`
        // convention but synthesize a case-name lookup instead.
        let isEnumCases = node.attributeName.trimmedDescription == "SBJPropertyInfoEnum"
        if isEnumCases {
            let checks = names.map { name in
                "case \"\(name)\": return Self.\(name)Info"
            }.joined(separator: "\n            ")
            return [DeclSyntax(stringLiteral: """
            public static func sbjCaseInfo(for caseName: String) -> SBJPropertyInfo? {
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
            "if keyPath == \\\(typeName).\(name) {\n\(index == 0 ? "        " : "    ")return Self.\(name)Info\n}"
        }.joined(separator: "\n")

        let fallback = "return Self._propertyInfo(for: keyPath)"

        // Use direct key-path equality rather than switching on AnyKeyPath.
        // The latter can crash SILGen for class extensions in Swift 6.4.
        var members: [DeclSyntax] = [DeclSyntax(stringLiteral: """
        public static func _extensionPropertyInfo<Value>(for keyPath: KeyPath<\(typeName), Value>) -> SBJPropertyInfo? {
            \(checks)
            \(fallback)
        }
        """)]
        if !hasCustomPublicLookup {
            members.append(DeclSyntax(stringLiteral: """
            public static func propertyInfo<Value>(for keyPath: KeyPath<\(typeName), Value>) -> SBJPropertyInfo? {
                _extensionPropertyInfo(for: keyPath)
            }
            """))
        }
        return members
    }

    private enum Error: Swift.Error {
        case onlyExtensions
    }
}
