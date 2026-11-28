import SBJStructureMacroSupport
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Synthesizes static property-info lookup and discoverable computed descriptors from `fooInfo` members in an extension.
/// The generated extension lookup falls back to the primary type's `_nomenclature(for:)`.
public struct SBJStructureExtensionMacro: MemberMacro {
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
        var properties: [String] = []
        for member in extensionDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            for binding in variable.bindings {
                guard !extensionDecl.modifiers.contains(where: { ["private", "fileprivate"].contains($0.name.text) }),
                      SBJStructureGeneration.isComputed(binding),
                      SBJStructureGeneration.isDiscoverable(variable, binding: binding),
                      let description = SBJStructureGeneration.propertyDescription(
                        variable: variable, binding: binding, rootType: typeName,
                        defaultVisibility: extensionDecl.modifiers.contains(where: { $0.name.text == "public" }) ? ".publicAccess" : extensionDecl.modifiers.contains(where: { $0.name.text == "package" }) ? ".packageAccess" : ".internalAccess",
                        in: context
                      ) else { continue }
                properties.append(description.entry)
            }
        }
        if !properties.isEmpty {
            let entries = properties.joined(separator: ",\n                ")
            members.append(DeclSyntax(stringLiteral: """
            public static var sbjProperties: [SBJPropertyMetadata<\(typeName)>] {
                Self._sbjDeclaredProperties + [
                    \(entries)
                ]
            }
            """))
        }
        return members
    }

    private enum Error: Swift.Error {
        case onlyExtensions
    }
}
