import SwiftCompilerPlugin
import SwiftSyntaxMacros
import SBJStructureMacroSupport

@main
struct SBJStructurePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SBJStructureMacro.self,
        SBJStructureExtensionMacro.self,
        SBJNomenclatureMacro.self,
        SBJAutoNomenclatureMacro.self,
        SBJDesignatedInitMacro.self,
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
        SBJDurationMacro.self,
        SBJDataMacro.self,
        SBJColorPresentationMacro.self,
        SBJArrayPresentationMacro.self,
        SBJDictionaryPresentationMacro.self,
        SBJSetPresentationMacro.self,
        SBJFieldPresentationMacro.self,
        SBJComputedMacro.self,
        SBJStringPresentationMacro.self,

    ]
}
