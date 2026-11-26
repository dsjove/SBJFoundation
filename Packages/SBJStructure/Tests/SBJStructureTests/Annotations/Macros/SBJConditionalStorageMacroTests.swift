import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import XCTest
import SBJStructureMacros

final class SBJConditionalStorageMacroTests: XCTestCase {
    func testConditionalStorageProducesWarningAndConservativeWitnesses() throws {
        let declaration: DeclSyntax = """
            @SBJStructure
            private struct ConditionalStorage {
                var value: Int = 0
                #if swift(>=6.0)
                #if DEBUG
                var hidden: Int = 1
                #else
                var other: Int = 2
                #endif
                #endif
            }
            """
        let structure = try XCTUnwrap(declaration.as(StructDeclSyntax.self))
        let attribute = try XCTUnwrap(structure.attributes.first?.as(AttributeSyntax.self))
        let context = BasicMacroExpansionContext()
        let members = try SBJStructureMacro.expansion(
            of: attribute, providingMembersOf: structure, conformingTo: [], in: context
        )

        let warnings = context.diagnostics.filter { $0.diagMessage.severity == .warning }
        XCTAssertEqual(warnings.count, 1)
        XCTAssertEqual(warnings.first?.message,
            "SBJStructure cannot fully inspect lazy, destructured or conditional instance declarations; supply explicit state comparison and resource traversal when required")

        let comparison = members.compactMap { $0.as(FunctionDeclSyntax.self) }
            .first { $0.name.text == "_sbjStructuralEquals" }
        XCTAssertEqual(comparison?.body?.statements.trimmedDescription, "false")
        let complete = members.compactMap { $0.as(VariableDeclSyntax.self) }
            .flatMap { Array($0.bindings) }
            .first { $0.pattern.trimmedDescription == "sbjHasCompleteStoredDefinition" }
        XCTAssertEqual(complete?.accessorBlock?.trimmedDescription, "{ false }")
    }
}
