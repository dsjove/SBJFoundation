import Foundation
import SwiftSyntax
import SBJStructureMacroSupport

/// Editor-specific source generation. Structural analysis and conformance
/// generation remain in SBJStructureGeneration and are reused by both macros.
struct SBJEditorGeneration: SBJMacroGenerationLayer {
    func additionalConformances(isStruct: Bool, hasEnumPayload: Bool) -> [String] {
        if isStruct { return ["SBJSwiftUIEditable"] }
        return hasEnumPayload ? ["SBJEditableAssociatedEnum"] : []
    }

    func nonStructuralProperty(name: String) -> String? { nonStructuralPropertyDescriptor(name: name) }
    func storedProperty(name: String, disclosure: String) -> String? { storedPropertyDescriptor(name: name, disclosure: disclosure) }

    func structMembers(access: String, fields: [String]) -> [DeclSyntax] {
        [DeclSyntax(stringLiteral: """
        @MainActor
        \(access)static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
            [
                \(fields.joined(separator: ",\n"))
            ]
        }
        """)]
    }

    func enumMembers(access: String, cases: [SBJStructureGeneration.EnumCaseInfo]) -> [DeclSyntax] {
        let descriptors = cases.map { info in
            enumCaseDescriptor(info).replacingOccurrences(
                of: "name: \(info.displayNameExpression),",
                with: "name: Self.sbjCaseInfo(for: \(String(reflecting: info.caseName)))?.title ?? \(info.displayNameExpression),"
            )
        }.joined(separator: ",\n            ")
        return [DeclSyntax(stringLiteral: """
        @MainActor
        \(access)static var sbjEditorEnumCases: [SBJEditorEnumCase<Self>] {
            [
                \(descriptors)
            ]
        }
        """)]
    }

    func nonStructuralPropertyDescriptor(name: String) -> String {
        "SBJEditorPropertyDescriptor<Self>(nonStructuralName: \"\(name)\".uncamelCased, \\.\(name))"
    }

    func storedPropertyDescriptor(name: String, disclosure: String) -> String {
        "SBJEditorPropertyDescriptor<Self>(name: \"\(name)\".uncamelCased, \\.\(name), disclosureMode: \(disclosure))"
    }

    func enumCaseDescriptor(_ info: SBJStructureGeneration.EnumCaseInfo) -> String {
        let pattern = SBJStructureGeneration.casePattern(info)
        let defaultBody = SBJStructureGeneration.enumOptionalCreatorBody(for: info)
        let associated = info.parameters.enumerated().map { index, parameter in
            enumAssociatedValueDescriptor(info: info, parameterIndex: index, parameter: parameter)
        }.joined(separator: ",\n                    ")

        return """
        SBJEditorEnumCase<Self>(
            name: \(info.displayNameExpression),
            matches: { value in
                if case \(pattern) = value { return true }
                return false
            },
            makeDefault: {
                \(defaultBody)
            },
            associatedValues: [
                \(associated)
            ]
        )
        """
    }

    func enumAssociatedValueDescriptor(
        info: SBJStructureGeneration.EnumCaseInfo,
        parameterIndex: Int,
        parameter: SBJStructureGeneration.EnumParameter
    ) -> String {
        let getPatternNames = info.parameters.enumerated().map { index, candidate in
            index == parameterIndex ? candidate.variableName : "_"
        }
        let getPattern = SBJStructureGeneration.caseLetPattern(info, names: getPatternNames)

        let setterPatternNames = info.parameters.enumerated().map { index, candidate in
            index == parameterIndex ? "_" : candidate.variableName
        }
        let setterPattern = SBJStructureGeneration.caseLetPattern(info, names: setterPatternNames)
        let setterCaseKeyword = setterPatternNames.contains(where: { $0 != "_" }) ? "case let" : "case"

        var replacementNames = info.parameters.map(\.variableName)
        replacementNames[parameterIndex] = "newValue"
        let reconstruction = SBJStructureGeneration.caseConstruction(info, values: replacementNames)

        return """
        SBJEditorAssociatedValue<Self>(
            name: \(parameter.fieldNameExpression),
            get: { root in
                guard case let \(getPattern) = root else {
                    preconditionFailure("Associated value accessed while enum is in a different case")
                }
                return \(parameter.variableName)
            },
            set: { root, newValue in
                guard \(setterCaseKeyword) \(setterPattern) = root else { return }
                root = \(reconstruction)
            }
        )
        """
    }

}
