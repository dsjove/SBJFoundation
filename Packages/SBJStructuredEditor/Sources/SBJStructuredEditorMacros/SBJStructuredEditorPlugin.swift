import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SBJStructuredEditorPlugin: CompilerPlugin {
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
