import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SBJStructurePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SBJStructureMacro.self,
        SBJPropertyInfoMacro.self,
        SBJEditorDisclosureMacro.self,
        SBJDesignatedInitMacro.self,
        SBJEditorExcludeMacro.self,
        SBJEditorPropertyMacro.self,
        SBJEditorFontFamilyMacro.self,
        SBJStringMacro.self,
        SBJEditorStringMacro.self,
        SBJEditorArrayMacro.self,
        SBJEditorSetMacro.self,
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
