import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SBJStructurePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SBJEditableMacro.self,
        SBJEditorDisclosureMacro.self,
        SBJEditorExcludeMacro.self,
        SBJEditorPropertyMacro.self,
        SBJEditorStringMacro.self,
        SBJEditorArrayMacro.self,
        SBJEditorSetMacro.self,
    ]
}
