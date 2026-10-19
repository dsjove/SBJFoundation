import SwiftCompilerPlugin
import SwiftSyntaxMacros
import SBJStructureMacroSupport

@main
struct SBJDataDefinitionPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SBJStructureMacro.self,
        SBJPropertyInfoMacro.self,
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
        SBJDataMacro.self,
        SBJColorMacro.self,
    ]
}
