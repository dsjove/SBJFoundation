import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SBJStructurePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SBJStructureMacro.self,
        SBJEditorDisclosureMacro.self,
        SBJDesignatedInitMacro.self,
        SBJNotEditableMacro.self,
        SBJEditorPropertyMacro.self,
        SBJPresentationMacro.self,
        SBJStringMacro.self,
        SBJIntegerMacro.self,
        SBJNumberMacro.self,
        SBJUnitValueMacro.self,
        SBJOptionalMacro.self,
        SBJArrayMacro.self,
        SBJSetMacro.self,
        SBJDictionaryMacro.self,
        SBJURLMacro.self,
        SBJUUIDMacro.self,
        SBJDateMacro.self,
        SBJDataMacro.self,
        SBJColorMacro.self,
    ]
}
