import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SBJStructureMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return structMembers(for: structDecl, in: context)
        }
        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return enumMembers(for: enumDecl, in: context)
        }
        throw SBJStructureMacroError.onlyStructsOrEnums
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let conformance: String
        if declaration.is(StructDeclSyntax.self) {
            conformance = "SBJEditable, SBJSwiftUIEditable"
        } else if declaration.is(EnumDeclSyntax.self) {
            conformance = "SBJEditableAssociatedEnum, SBJStructuredEnum"
        } else {
            throw SBJStructureMacroError.onlyStructsOrEnums
        }

        let extensionDecl: DeclSyntax = """
        extension \(type.trimmed): \(raw: conformance) {}
        """
        return [extensionDecl.cast(ExtensionDeclSyntax.self)]
    }

    // MARK: - Structs

    private static func structMembers(
        for structDecl: StructDeclSyntax,
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        let codedNames = codingKeyNames(in: structDecl)
        let access = effectiveAccessPrefix(modifiers: structDecl.modifiers, in: context)

        var propertyEntries: [String] = []
        var editableEntries: [String] = []
        var entries: [String] = []
        var contentMembers: [String] = []
        var invariantStatements: [String] = []
        let hasExplicitHasContent = structDecl.memberBlock.members.contains { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { return false }
            return variable.bindings.contains { binding in
                binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "hasContent"
            }
        }
        let hasExplicitInvariant = structDecl.memberBlock.members.contains { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self) else { return false }
            return function.name.text == "invariant"
        }
        let hasExplicitStructuralEquals = structDecl.memberBlock.members.contains { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self) else { return false }
            return function.name.text == "sbjStructuralEquals"
        }
        let hasExplicitDefaultValue = structDecl.memberBlock.members.contains { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self) else { return false }
            return function.name.text == "sbjDefaultValue"
        }

        for member in structDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            guard !variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }) else {
                continue
            }
            for binding in variable.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                let name = identifier.identifier.text

                // Writable computed properties are normally outside the model
                // structure. @SBJEditorProperty explicitly opts one into editor
                // generation only. It does not become structural metadata.
                if binding.accessorBlock != nil {
                    if hasAttribute(named: "SBJEditorProperty", on: variable) {
                        editableEntries.append(
                            "SBJEditableField<Self>(editorOnlyName: \"\(name)\".uncamelCased, \\.\(name))"
                        )
                        entries.append(
                            "SBJEditorPropertyDescriptor<Self>(editorOnlyName: \"\(name)\".uncamelCased, \\.\(name))"
                        )
                    }
                    continue
                }

                if let codedNames, !codedNames.contains(name) { continue }

                var constraintMetadata: [String] = []
                var hintMetadata: [String] = []
                let kind = propertyKind(for: binding, variable: variable)
                diagnoseDeclarationIssues(
                    binding: binding,
                    variable: variable,
                    propertyName: name,
                    identifier: identifier.identifier,
                    context: context
                )

                // Structural content and invariant generation is independent of
                // editor eligibility. Read-only and @SBJNotEditable properties
                // remain part of the declared model and are validated when a
                // consumer explicitly invokes the invariant.
                contentMembers.append(name)
                let arrayOptions = arrayOptions(on: variable)
                let setOptions = setOptions(on: variable)
                if let itemTitleKey = arrayOptions.title {
                    invariantStatements.append("try SBJInvariantCheck.validate(\(name), at: keyPath.appending(\\Self.\(name)), itemTitleKey: \(swiftStringLiteral(itemTitleKey)))")
                } else if let itemTitleKey = setOptions.title {
                    invariantStatements.append("try SBJInvariantCheck.validate(\(name), at: keyPath.appending(\\Self.\(name)), itemTitleKey: \(swiftStringLiteral(itemTitleKey)))")
                } else {
                    invariantStatements.append("try SBJInvariantCheck.validate(\(name), at: keyPath.appending(\\Self.\(name)))")
                }

                let textConstraints = editorTextConstraints(on: variable)
                if let textStyle = textStyle(on: variable) {
                    hintMetadata.append(".textStyle(\(textStyle))")
                }
                let textInputOptions = textInputOptions(on: variable)
                if let autocorrect = textInputOptions.autocorrect {
                    hintMetadata.append(".textAutocorrection(\(autocorrect))")
                }
                if let capitalization = textInputOptions.capitalization {
                    hintMetadata.append(".textCapitalization(\(capitalization))")
                }
                if textConstraints.minLength != nil || textConstraints.maxLength != nil || textConstraints.trimming != nil {
                    let minLength = textConstraints.minLength ?? "nil"
                    let maxLength = textConstraints.maxLength ?? "nil"
                    if let trimming = textConstraints.trimming {
                        invariantStatements.append("try SBJInvariantCheck.requireText(\(name), minLength: \(minLength), maxLength: \(maxLength), trimming: \(trimming), at: keyPath.appending(\\Self.\(name)))")
                    } else {
                        invariantStatements.append("try SBJInvariantCheck.requireText(\(name), minLength: \(minLength), maxLength: \(maxLength), at: keyPath.appending(\\Self.\(name)))")
                    }
                    if textConstraints.minLength != nil || textConstraints.maxLength != nil {
                        constraintMetadata.append(".textLength(min: \(minLength), max: \(maxLength))")
                    }
                }
                let integerConstraints = editorIntegerConstraints(on: variable)
                if let integerRange = integerConstraints.range {
                    invariantStatements.append("try SBJInvariantCheck.requireRange(\(name), \(integerRange), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".integerRange(\(integerRange))")
                }
                if let integerMinimum = integerConstraints.min {
                    invariantStatements.append("try SBJInvariantCheck.requireMinimum(\(name), \(integerMinimum), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".integerMinimum(\(integerMinimum))")
                }
                let numberConstraints = editorNumberConstraints(on: variable)
                if let numberRange = numberConstraints.range {
                    invariantStatements.append("try SBJInvariantCheck.requireRange(\(name), \(numberRange), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".numberRange(\(numberRange))")
                }
                if let numberMinimum = numberConstraints.min {
                    invariantStatements.append("try SBJInvariantCheck.requireMinimum(\(name), \(numberMinimum), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".numberMinimum(\(numberMinimum))")
                }
                if let unitMinimum = unitValueMinimum(on: variable) {
                    invariantStatements.append("try SBJInvariantCheck.requireMinimum(\(name), \(unitMinimum), at: keyPath.appending(\\Self.\(name)))")
                }
                if let required = editorOptionalRequired(on: variable) {
                    invariantStatements.append("try SBJInvariantCheck.requirePresent(\(name), required: \(required), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".required(\(required))")
                }
                if arrayOptions.unique == "true", arrayOptions.uniqueBy != nil {
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(identifier.identifier),
                            message: ConflictingArrayUniquenessDiagnostic(name: name)
                        )
                    )
                }
                if arrayOptions.minCount != nil || arrayOptions.maxCount != nil {
                    let minCount = arrayOptions.minCount ?? "nil"
                    let maxCount = arrayOptions.maxCount ?? "nil"
                    invariantStatements.append("try SBJInvariantCheck.requireCount(\(name), minCount: \(minCount), maxCount: \(maxCount), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".count(min: \(minCount), max: \(maxCount))")
                }
                if arrayOptions.unique == "true", arrayOptions.uniqueBy == nil {
                    invariantStatements.append("try SBJInvariantCheck.requireUnique(\(name), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".unique")
                }
                if let uniqueBy = arrayOptions.uniqueBy {
                    invariantStatements.append("try SBJInvariantCheck.requireUnique(\(name), by: \(uniqueBy), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".uniqueBy(\(swiftStringLiteral(uniqueBy)))")
                }

                if setOptions.minCount != nil || setOptions.maxCount != nil {
                    let minCount = setOptions.minCount ?? "nil"
                    let maxCount = setOptions.maxCount ?? "nil"
                    invariantStatements.append("try SBJInvariantCheck.requireCount(\(name), minCount: \(minCount), maxCount: \(maxCount), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".count(min: \(minCount), max: \(maxCount))")
                }

                let dictionaryOptions = dictionaryOptions(on: variable)
                if dictionaryOptions.minCount != nil || dictionaryOptions.maxCount != nil {
                    let minCount = dictionaryOptions.minCount ?? "nil"
                    let maxCount = dictionaryOptions.maxCount ?? "nil"
                    invariantStatements.append("try SBJInvariantCheck.requireCount(\(name), minCount: \(minCount), maxCount: \(maxCount), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".count(min: \(minCount), max: \(maxCount))")
                }

                let dataOptions = dataOptions(on: variable)
                if dataOptions.min != nil || dataOptions.max != nil || dataOptions.modulo != nil {
                    let min = dataOptions.min ?? "nil"
                    let max = dataOptions.max ?? "nil"
                    let modulo = dataOptions.modulo ?? "nil"
                    invariantStatements.append("try SBJInvariantCheck.requireData(\(name), min: \(min), max: \(max), modulo: \(modulo), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".dataSize(min: \(min), max: \(max), modulo: \(modulo))")
                }

                if uuidNonzero(on: variable) == "true" {
                    invariantStatements.append("try SBJInvariantCheck.requireNonzero(\(name), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".uuidNonzero")
                }

                if let dateRange = dateRange(on: variable) {
                    invariantStatements.append("try SBJInvariantCheck.requireRange(\(name), \(dateRange), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".dateRange(\(dateRange))")
                }
                if let allowedURLKinds = urlAllowedKinds(on: variable) {
                    invariantStatements.append("try SBJInvariantCheck.requireURL(\(name), allowed: \(allowedURLKinds), at: keyPath.appending(\\Self.\(name)))")
                    constraintMetadata.append(".urlKinds(\(allowedURLKinds))")
                }

                if let presentation = propertyPresentation(on: variable) {
                    hintMetadata.append(".presentation(\(presentation))")
                }

                if let colorAlpha = colorAlpha(on: variable) {
                    hintMetadata.append(".colorSupportsAlpha(\(colorAlpha))")
                }

                if let reorderable = arrayOptions.reorderable {
                    hintMetadata.append(".reorderable(\(reorderable))")
                }
                if let title = arrayOptions.title ?? setOptions.title {
                    hintMetadata.append(".itemTitle(\"\(title)\")")
                }

                let constraints = constraintMetadata.joined(separator: ", ")
                let hints = hintMetadata.joined(separator: ", ")
                propertyEntries.append(
                    "SBJPropertyMetadata<Self>(sourceName: \"\(name)\", displayName: \"\(name)\".uncamelCased, keyPath: \\Self.\(name), kind: \(kind), constraints: [\(constraints)], hints: [\(hints)], info: Self.propertyInfo(for: \\Self.\(name)))"
                )

                // Everything below this point is editor-only.
                if hasAttribute(named: "SBJNotEditable", on: variable) { continue }

                // Immutable stored properties remain part of structure metadata,
                // export, content checks, and invariants, but are simply not editable.
                if variable.bindingSpecifier.tokenKind == .keyword(.let) { continue }

                editableEntries.append(
                    "SBJEditableField<Self>(name: \"\(name)\".uncamelCased, \\.\(name))"
                )
                entries.append(
                    "SBJEditorPropertyDescriptor<Self>(name: \"\(name)\".uncamelCased, \\.\(name))"
                )
            }
        }

        let propertyBody = propertyEntries.joined(separator: ",\n")
        let editableBody = editableEntries.joined(separator: ",\n")
        let body = entries.joined(separator: ",\n")
        var result: [DeclSyntax] = [
            DeclSyntax(stringLiteral: """
            \(access)static var sbjProperties: [SBJPropertyMetadata<Self>] {
                [
                    \(propertyBody)
                ]
            }
            """),
            DeclSyntax(stringLiteral: """
            \(access)static var sbjEditableFields: [SBJEditableField<Self>] {
                [
                    \(editableBody)
                ]
            }
            """),
            DeclSyntax(stringLiteral: """
            @MainActor
            \(access)static var sbjEditorFields: [SBJEditorPropertyDescriptor<Self>] {
                [
                    \(body)
                ]
            }
            """)
        ]

        let contentExpression = contentMembers.isEmpty
            ? "true"
            : contentMembers.map { "SBJContentCheck.hasContent(\($0))" }.joined(separator: " ||\n")
        result.append(
            DeclSyntax(stringLiteral: """
            \(access)var _hasContent: Bool {
                \(contentExpression)
            }
            """)
        )

        if !hasExplicitHasContent {
            result.append(
                DeclSyntax(stringLiteral: """
                \(access)var hasContent: Bool {
                    _hasContent
                }
                """)
            )
        }

        let invariantBody = invariantStatements.isEmpty ? "" : invariantStatements.joined(separator: "\n")
        result.append(
            DeclSyntax(stringLiteral: """
            \(access)func _invariant(at keyPath: SBJValidationKeyPath) throws {
                \(invariantBody)
            }
            """)
        )
        if !hasExplicitInvariant {
            result.append(
                DeclSyntax(stringLiteral: """
                \(access)func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }
                """)
            )
        }

        let structuralExpression = contentMembers.isEmpty
            ? "true"
            : contentMembers.map { "SBJStructuralCompare.equals(self.\($0), other.\($0))" }.joined(separator: " &&\n")
        result.append(
            DeclSyntax(stringLiteral: """
            \(access)func _sbjStructuralEquals(_ other: Self) -> Bool {
                \(structuralExpression)
            }
            """)
        )
        if !hasExplicitStructuralEquals {
            result.append(
                DeclSyntax(stringLiteral: """
                \(access)func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
                """)
            )
        }

        if !hasExplicitDefaultValue, canInitializeWithoutArguments(structDecl) {
            result.append(
                DeclSyntax(stringLiteral: """
                \(access)static func sbjDefaultValue() -> Self? {
                    .init()
                }
                """)
            )
        }

        return result
    }

    private static func canInitializeWithoutArguments(_ structDecl: StructDeclSyntax) -> Bool {
        let initializers = structDecl.memberBlock.members.compactMap {
            $0.decl.as(InitializerDeclSyntax.self)
        }

        if !initializers.isEmpty {
            return initializers.contains { initializer in
                let declaration = initializer.trimmedDescription
                let header = declaration.split(separator: "{", maxSplits: 1).first.map(String.init) ?? declaration
                guard !header.contains("init?"),
                      !header.contains("init!"),
                      !header.contains(" async"),
                      !header.contains(" throws"),
                      !header.contains(" rethrows") else { return false }
                return initializer.signature.parameterClause.parameters.allSatisfy { parameter in
                    parameter.defaultValue != nil
                }
            }
        }

        // With no explicit initializer, Swift synthesizes `init()` when every
        // stored instance property has an initializer. Computed/static members
        // do not participate.
        for member in structDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            if variable.modifiers.contains(where: {
                $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class)
            }) { continue }

            for binding in variable.bindings {
                guard binding.accessorBlock == nil else { continue }
                if binding.initializer != nil { continue }

                // Stored Optional properties are implicitly initialized to nil,
                // even when there is no explicit `= nil` initializer.
                if binding.typeAnnotation?.type.as(OptionalTypeSyntax.self) != nil {
                    continue
                }

                return false
            }
        }
        return true
    }

    // MARK: - Associated-value enums

    private struct EnumParameter {
        let type: String
        let fieldNameExpression: String
        let constructorLabel: String?
        let variableName: String
    }

    private struct EnumCaseInfo {
        let caseName: String
        let displayNameExpression: String
        let parameters: [EnumParameter]
    }

    private static func enumMembers(
        for enumDecl: EnumDeclSyntax,
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        let access = effectiveAccessPrefix(modifiers: enumDecl.modifiers, in: context)
        let cases = enumCases(in: enumDecl)
        let hasExplicitStructuralEquals = enumDecl.memberBlock.members.contains { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self) else { return false }
            return function.name.text == "sbjStructuralEquals"
        }

        let caseEntries = cases.map(enumCaseDescriptor).joined(separator: ",\n            ")
        let failableCreatorBody = enumFailableCreatorBody(for: cases)
        let sourceCaseNames = cases.map { swiftStringLiteral($0.caseName) }.joined(separator: ", ")
        let sourceCaseNameSwitch = cases.map { info in
            "case \(casePattern(info)): \(swiftStringLiteral(info.caseName))"
        }.joined(separator: "\n        ")

        var result: [DeclSyntax] = [
            DeclSyntax(stringLiteral: """
            \(access)static var sbjCaseNames: [String] {
                [\(sourceCaseNames)]
            }
            """),
            DeclSyntax(stringLiteral: """
            var sbjCaseName: String {
                switch self {
                \(sourceCaseNameSwitch)
                }
            }
            """),
            DeclSyntax(stringLiteral: """
            \(access)static func sbjCaseName(for value: Any) -> String? {
                guard let value = value as? Self else { return nil }
                return value.sbjCaseName
            }
            """),
            DeclSyntax(stringLiteral: """
            @MainActor
            \(access)static var sbjEditorEnumCases: [SBJEditorEnumCase<Self>] {
                [
                    \(caseEntries)
                ]
            }
            """),
            DeclSyntax(stringLiteral: """
            \(access)static func sbjCreateDefaultValueIfPossible() -> Self? {
                \(failableCreatorBody)
            }
            """),
        ]

        let structuralCases = cases.map(enumStructuralComparisonCase).joined(separator: "\n        ")
        result.append(
            DeclSyntax(stringLiteral: """
            \(access)func _sbjStructuralEquals(_ other: Self) -> Bool {
                switch (self, other) {
                \(structuralCases)
                default: return false
                }
            }
            """)
        )
        if !hasExplicitStructuralEquals {
            result.append(
                DeclSyntax(stringLiteral: """
                \(access)func sbjStructuralEquals(_ other: Self) -> Bool {
                    _sbjStructuralEquals(other)
                }
                """)
            )
        }
        return result
    }

    private static func enumCases(in declaration: EnumDeclSyntax) -> [EnumCaseInfo] {
        var result: [EnumCaseInfo] = []
        for member in declaration.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for element in caseDecl.elements {
                let caseName = element.name.text
                let parametersSyntax = element.parameterClause.map { Array($0.parameters) } ?? []
                let count = parametersSyntax.count
                let parameters = parametersSyntax.enumerated().map { offset, parameter in
                    let firstName = parameter.firstName?.text
                    let secondName = parameter.secondName?.text
                    let constructorLabel: String?
                    if let firstName, firstName != "_" {
                        constructorLabel = firstName
                    } else {
                        constructorLabel = nil
                    }

                    let semanticName: String?
                    if let secondName, secondName != "_" {
                        semanticName = secondName
                    } else if let firstName, firstName != "_" {
                        semanticName = firstName
                    } else {
                        semanticName = nil
                    }

                    let fieldNameExpression: String
                    if let semanticName {
                        fieldNameExpression = "\"\(semanticName)\".uncamelCased"
                    } else if count == 1 {
                        fieldNameExpression = "\"Value\""
                    } else {
                        fieldNameExpression = "\"Value \(offset + 1)\""
                    }

                    return EnumParameter(
                        type: parameter.type.trimmedDescription,
                        fieldNameExpression: fieldNameExpression,
                        constructorLabel: constructorLabel,
                        variableName: "_sbjValue\(offset)"
                    )
                }
                result.append(
                    EnumCaseInfo(
                        caseName: caseName,
                        displayNameExpression: "\"\(caseName)\".uncamelCased",
                        parameters: parameters
                    )
                )
            }
        }
        return result
    }

    private static func enumCaseDescriptor(_ info: EnumCaseInfo) -> String {
        let pattern = casePattern(info)
        let defaultBody = enumOptionalCreatorBody(for: info)
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

    private static func enumAssociatedValueDescriptor(
        info: EnumCaseInfo,
        parameterIndex: Int,
        parameter: EnumParameter
    ) -> String {
        let getPatternNames = info.parameters.enumerated().map { index, candidate in
            index == parameterIndex ? candidate.variableName : "_"
        }
        let getPattern = caseLetPattern(info, names: getPatternNames)

        let setterPatternNames = info.parameters.enumerated().map { index, candidate in
            index == parameterIndex ? "_" : candidate.variableName
        }
        let setterPattern = caseLetPattern(info, names: setterPatternNames)
        let setterCaseKeyword = setterPatternNames.contains(where: { $0 != "_" }) ? "case let" : "case"

        var replacementNames = info.parameters.map(\.variableName)
        replacementNames[parameterIndex] = "newValue"
        let reconstruction = caseConstruction(info, values: replacementNames)

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

    private static func enumOptionalCreatorBody(for info: EnumCaseInfo) -> String {
        guard !info.parameters.isEmpty else { return "return Self.\(info.caseName)" }
        let guards = info.parameters.map { parameter in
            "guard let \(parameter.variableName) = SBJDefaultValue.value(for: \(parameter.type).self) else { return nil }"
        }.joined(separator: "\n                ")
        return """
        \(guards)
                return \(caseConstruction(info, values: info.parameters.map(\.variableName)))
        """
    }

    private static func enumFailableCreatorBody(for cases: [EnumCaseInfo]) -> String {
        guard !cases.isEmpty else { return "return nil" }
        let attempts = cases.map { info in
            let caseBody = enumOptionalCreatorBody(for: info)
            return """
            if let value: Self = ({ () -> Self? in
                \(caseBody)
            })() {
                return value
            }
            """
        }.joined(separator: "\n        ")
        return """
        \(attempts)
        return nil
        """
    }

    private static func enumStructuralComparisonCase(_ info: EnumCaseInfo) -> String {
        guard !info.parameters.isEmpty else {
            return "case (.\(info.caseName), .\(info.caseName)): return true"
        }
        let lhsNames = info.parameters.indices.map { "_sbjLhs\($0)" }
        let rhsNames = info.parameters.indices.map { "_sbjRhs\($0)" }
        let lhsPattern = caseLetPattern(info, names: lhsNames)
        let rhsPattern = caseLetPattern(info, names: rhsNames)
        let comparisons = zip(lhsNames, rhsNames).map {
            "SBJStructuralCompare.equals(\($0), \($1))"
        }.joined(separator: " && ")
        return "case let (\(lhsPattern), \(rhsPattern)): return \(comparisons)"
    }

    private static func casePattern(_ info: EnumCaseInfo) -> String {
        guard !info.parameters.isEmpty else { return ".\(info.caseName)" }
        return ".\(info.caseName)(\(Array(repeating: "_", count: info.parameters.count).joined(separator: ", ")))"
    }

    private static func caseLetPattern(_ info: EnumCaseInfo, names: [String]) -> String {
        guard !names.isEmpty else { return ".\(info.caseName)" }
        return ".\(info.caseName)(\(names.joined(separator: ", ")))"
    }

    private static func caseConstruction(_ info: EnumCaseInfo, values: [String]) -> String {
        guard !values.isEmpty else { return ".\(info.caseName)" }
        let arguments = zip(info.parameters, values).map { parameter, value in
            if let label = parameter.constructorLabel {
                return "\(label): \(value)"
            }
            return value
        }.joined(separator: ", ")
        return ".\(info.caseName)(\(arguments))"
    }

    // MARK: - Shared metadata helpers

    private static func effectiveAccessPrefix(
        modifiers: DeclModifierListSyntax,
        in context: some MacroExpansionContext
    ) -> String {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open):
                return "public "
            case .keyword(.private), .keyword(.fileprivate), .keyword(.internal), .keyword(.package):
                return ""
            default:
                continue
            }
        }

        for syntax in context.lexicalContext {
            guard let extensionDecl = syntax.as(ExtensionDeclSyntax.self) else { continue }
            if extensionDecl.modifiers.contains(where: { modifier in
                modifier.name.tokenKind == .keyword(.public) ||
                modifier.name.tokenKind == .keyword(.open)
            }) {
                return "public "
            }
        }

        return ""
    }



    private static func propertyPresentation(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJPresentation" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments,
                  let argument = arguments.first else { return nil }
            return argument.expression.trimmedDescription
        }
        return nil
    }


    private static func textStyle(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJString" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments,
                  let argument = arguments.first else {
                return nil
            }

            switch argument.expression.trimmedDescription {
            case ".multiline", "SBJStringStyle.multiline":
                return ".multiline"
            case ".singleLine", "SBJStringStyle.singleLine":
                return ".singleLine"
            case ".sheetEdit", "SBJStringStyle.sheetEdit":
                return ".sheetEdit"
            default:
                return nil
            }
        }
        return nil
    }


    private static func textInputOptions(on variable: VariableDeclSyntax) -> (autocorrect: String?, capitalization: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJString" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { return (nil, nil) }

            var autocorrect: String?
            var capitalization: String?
            for argument in arguments {
                switch argument.label?.text {
                case "autocorrect": autocorrect = argument.expression.trimmedDescription
                case "capitalization": capitalization = argument.expression.trimmedDescription
                default: break
                }
            }
            return (autocorrect, capitalization)
        }
        return (nil, nil)
    }


    private static func editorTextConstraints(on variable: VariableDeclSyntax) -> (minLength: String?, maxLength: String?, trimming: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJString" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { return (nil, nil, nil) }
            var minLength: String?
            var maxLength: String?
            var trimming: String?
            for argument in arguments {
                switch argument.label?.text {
                case "minLength": minLength = argument.expression.trimmedDescription
                case "maxLength": maxLength = argument.expression.trimmedDescription
                case "trimming": trimming = argument.expression.trimmedDescription
                default: break
                }
            }
            return (minLength, maxLength, trimming)
        }
        return (nil, nil, nil)
    }

    private static func editorNumberConstraints(on variable: VariableDeclSyntax) -> (range: String?, min: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJNumber" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else {
                return (nil, nil)
            }
            for argument in arguments where argument.label?.text == "range" {
                return (argument.expression.trimmedDescription, nil)
            }
            for argument in arguments where argument.label?.text == "min" {
                return (nil, argument.expression.trimmedDescription)
            }
        }
        return (nil, nil)
    }

    private static func unitValueMinimum(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJUnitValue" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { return nil }
            return arguments.first(where: { $0.label?.text == "min" })?.expression.trimmedDescription
        }
        return nil
    }

    private static func editorOptionalRequired(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJOptional" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { return "true" }
            for argument in arguments where argument.label?.text == "required" {
                return argument.expression.trimmedDescription
            }
            return "true"
        }
        return nil
    }

    private static func editorIntegerConstraints(on variable: VariableDeclSyntax) -> (range: String?, min: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJInteger" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else {
                return (nil, nil)
            }
            for argument in arguments where argument.label?.text == "range" {
                return (argument.expression.trimmedDescription, nil)
            }
            for argument in arguments where argument.label?.text == "min" {
                return (nil, argument.expression.trimmedDescription)
            }
        }
        return (nil, nil)
    }

    private static func swiftStringLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    private static func arrayOptions(on variable: VariableDeclSyntax) -> (reorderable: String?, title: String?, minCount: String?, maxCount: String?, unique: String?, uniqueBy: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJArray" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else {
                return ("true", nil, nil, nil, "false", nil)
            }

            var reorderable: String? = "true"
            var title: String?
            var minCount: String?
            var maxCount: String?
            var unique: String? = "false"
            var uniqueBy: String?
            for argument in arguments {
                switch argument.label?.text {
                case "reorderable":
                    switch argument.expression.trimmedDescription {
                    case "false": reorderable = "false"
                    case "true": reorderable = "true"
                    default: reorderable = nil
                    }
                case "title":
                    let expression = argument.expression.trimmedDescription
                    title = expression == "nil" ? nil : keyPathPropertyName(from: expression)
                case "minCount": minCount = argument.expression.trimmedDescription
                case "maxCount": maxCount = argument.expression.trimmedDescription
                case "unique": unique = argument.expression.trimmedDescription
                case "uniqueBy":
                    let expression = argument.expression.trimmedDescription
                    uniqueBy = expression == "nil" ? nil : expression
                default:
                    continue
                }
            }
            return (reorderable, title, minCount, maxCount, unique, uniqueBy)
        }
        return (nil, nil, nil, nil, nil, nil)
    }

    private static func setOptions(on variable: VariableDeclSyntax) -> (title: String?, minCount: String?, maxCount: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJSet" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else {
                return (nil, nil, nil)
            }
            var title: String?
            var minCount: String?
            var maxCount: String?
            for argument in arguments {
                switch argument.label?.text {
                case "title":
                    let expression = argument.expression.trimmedDescription
                    title = expression == "nil" ? nil : keyPathPropertyName(from: expression)
                case "minCount": minCount = argument.expression.trimmedDescription
                case "maxCount": maxCount = argument.expression.trimmedDescription
                default: continue
                }
            }
            return (title, minCount, maxCount)
        }
        return (nil, nil, nil)
    }

    private static func dictionaryOptions(on variable: VariableDeclSyntax) -> (minCount: String?, maxCount: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJDictionary" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else {
                return (nil, nil)
            }
            var minCount: String?
            var maxCount: String?
            for argument in arguments {
                switch argument.label?.text {
                case "minCount": minCount = argument.expression.trimmedDescription
                case "maxCount": maxCount = argument.expression.trimmedDescription
                default: continue
                }
            }
            return (minCount, maxCount)
        }
        return (nil, nil)
    }



    private static func diagnoseDeclarationIssues(
        binding: PatternBindingSyntax,
        variable: VariableDeclSyntax,
        propertyName: String,
        identifier: TokenSyntax,
        context: some MacroExpansionContext
    ) {
        if let type = binding.typeAnnotation?.type.trimmedDescription {
            let checks: [(String, (String) -> Bool, String)] = [
                ("SBJString", { supportsLeafType($0, allowed: stringTypes, allowArray: true) }, "String or a collection of String"),
                ("SBJInteger", { supportsLeafType($0, allowed: integerTypes, allowArray: true) }, "an integer type or a collection of integers"),
                ("SBJNumber", { supportsLeafType($0, allowed: numberTypes, allowArray: true) }, "Float, Double, CGFloat, Decimal, or a collection of those types"),
                ("SBJOptional", { isOptionalType($0) }, "an Optional property"),
                ("SBJArray", { isArrayType($0) }, "an Array property"),
                ("SBJSet", { isSetType($0) }, "a Set property"),
                ("SBJDictionary", { isDictionaryType($0) }, "a Dictionary property"),
                ("SBJUUID", { supportsLeafType($0, allowed: uuidTypes) }, "UUID or UUID?"),
                ("SBJDate", { supportsLeafType($0, allowed: dateTypes) }, "Date or Date?"),
                ("SBJURL", { supportsLeafType($0, allowed: ["URL", "Foundation.URL"]) }, "URL or URL?"),
                ("SBJData", { supportsLeafType($0, allowed: dataTypes) }, "Data or Data?"),
                ("SBJColor", { supportsLeafType($0, allowed: colorTypes) }, "CodableColor or CodableColor?")
            ]
            for (annotation, accepts, expectation) in checks where hasAttribute(named: annotation, on: variable) {
                if !accepts(type), isKnownSBJTypeSyntax(type) {
                    context.diagnose(Diagnostic(
                        node: Syntax(identifier),
                        message: InvalidAnnotationDeclarationDiagnostic(
                            annotation: annotation,
                            propertyName: propertyName,
                            detail: "requires \(expectation); found '\(type)'"
                        )
                    ))
                }
            }
        }

        let text = editorTextConstraints(on: variable)
        diagnoseMinMax(annotation: "SBJString", propertyName: propertyName, min: text.minLength, max: text.maxLength, identifier: identifier, context: context)

        let array = arrayOptions(on: variable)
        diagnoseMinMax(annotation: "SBJArray", propertyName: propertyName, min: array.minCount, max: array.maxCount, identifier: identifier, context: context)
        let set = setOptions(on: variable)
        diagnoseMinMax(annotation: "SBJSet", propertyName: propertyName, min: set.minCount, max: set.maxCount, identifier: identifier, context: context)
        let dictionary = dictionaryOptions(on: variable)
        diagnoseMinMax(annotation: "SBJDictionary", propertyName: propertyName, min: dictionary.minCount, max: dictionary.maxCount, identifier: identifier, context: context)
        let data = dataOptions(on: variable)
        diagnoseMinMax(annotation: "SBJData", propertyName: propertyName, min: data.min, max: data.max, identifier: identifier, context: context)
        if let modulo = literalInt(data.modulo), modulo <= 0 {
            context.diagnose(Diagnostic(
                node: Syntax(identifier),
                message: InvalidAnnotationDeclarationDiagnostic(annotation: "SBJData", propertyName: propertyName, detail: "modulo must be greater than zero")
            ))
        }

        if let allowed = urlAllowedKinds(on: variable), allowed.replacingOccurrences(of: " ", with: "") == "[]" {
            context.diagnose(Diagnostic(
                node: Syntax(identifier),
                message: InvalidAnnotationDeclarationDiagnostic(annotation: "SBJURL", propertyName: propertyName, detail: "allowed must contain at least one URL kind")
            ))
        }

        if let range = editorIntegerConstraints(on: variable).range,
           let (lower, upper) = literalIntRange(range), lower > upper {
            context.diagnose(Diagnostic(
                node: Syntax(identifier),
                message: InvalidAnnotationDeclarationDiagnostic(annotation: "SBJInteger", propertyName: propertyName, detail: "range lower bound cannot exceed upper bound")
            ))
        }
        if let range = editorNumberConstraints(on: variable).range,
           let (lower, upper) = literalDoubleRange(range), lower > upper {
            context.diagnose(Diagnostic(
                node: Syntax(identifier),
                message: InvalidAnnotationDeclarationDiagnostic(annotation: "SBJNumber", propertyName: propertyName, detail: "range lower bound cannot exceed upper bound")
            ))
        }
    }

    private static let stringTypes: Set<String> = ["String", "Swift.String"]
    private static let integerTypes: Set<String> = [
        "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
        "Swift.Int", "Swift.Int8", "Swift.Int16", "Swift.Int32", "Swift.Int64", "Swift.UInt", "Swift.UInt8", "Swift.UInt16", "Swift.UInt32", "Swift.UInt64"
    ]
    private static let numberTypes: Set<String> = ["Double", "Float", "CGFloat", "Decimal", "Swift.Double", "Swift.Float", "Foundation.Decimal", "CoreGraphics.CGFloat"]
    private static let uuidTypes: Set<String> = ["UUID", "Foundation.UUID"]
    private static let dateTypes: Set<String> = ["Date", "Foundation.Date"]
    private static let dataTypes: Set<String> = ["Data", "Foundation.Data"]
    private static let colorTypes: Set<String> = ["CodableColor"]

    private static func normalizedType(_ type: String) -> String {
        type.replacingOccurrences(of: " ", with: "")
    }

    private static func isOptionalType(_ type: String) -> Bool {
        let t = normalizedType(type)
        return t.hasSuffix("?") || t.hasPrefix("Optional<") || t.hasPrefix("Swift.Optional<")
    }

    private static func unwrapOptional(_ type: String) -> String {
        let t = normalizedType(type)
        if t.hasSuffix("?") { return String(t.dropLast()) }
        for prefix in ["Optional<", "Swift.Optional<"] where t.hasPrefix(prefix) && t.hasSuffix(">") {
            return String(t.dropFirst(prefix.count).dropLast())
        }
        return t
    }

    private static func isArrayType(_ type: String) -> Bool {
        let t = unwrapOptional(type)
        return (t.hasPrefix("[") && t.hasSuffix("]") && !t.contains(":")) || t.hasPrefix("Array<") || t.hasPrefix("Swift.Array<")
    }

    private static func isSetType(_ type: String) -> Bool {
        let t = unwrapOptional(type)
        return t.hasPrefix("Set<") || t.hasPrefix("Swift.Set<")
    }

    private static func isDictionaryType(_ type: String) -> Bool {
        let t = unwrapOptional(type)
        return (t.hasPrefix("[") && t.hasSuffix("]") && t.contains(":")) || t.hasPrefix("Dictionary<") || t.hasPrefix("Swift.Dictionary<")
    }

    private static func arrayElementType(_ type: String) -> String? {
        let t = unwrapOptional(type)
        if t.hasPrefix("[") && t.hasSuffix("]") && !t.contains(":") { return String(t.dropFirst().dropLast()) }
        for prefix in ["Array<", "Swift.Array<"] where t.hasPrefix(prefix) && t.hasSuffix(">") {
            return String(t.dropFirst(prefix.count).dropLast())
        }
        return nil
    }

    private static func supportsLeafType(_ type: String, allowed: Set<String>, allowArray: Bool = false) -> Bool {
        let leaf = unwrapOptional(type)
        if allowed.contains(leaf) { return true }
        if allowArray, let element = arrayElementType(leaf) { return allowed.contains(unwrapOptional(element)) }
        return false
    }

    private static func isKnownSBJTypeSyntax(_ type: String) -> Bool {
        let leaf = unwrapOptional(type)
        let scalars = stringTypes.union(integerTypes).union(numberTypes).union(uuidTypes).union(dateTypes).union(dataTypes).union(colorTypes).union(["Bool", "Swift.Bool", "URL", "Foundation.URL"])
        if scalars.contains(leaf) { return true }
        if isArrayType(leaf) || isSetType(leaf) || isDictionaryType(leaf) { return true }
        return false
    }

    private static func literalInt(_ expression: String?) -> Int? {
        guard let expression else { return nil }
        return Int(expression.replacingOccurrences(of: "_", with: ""))
    }

    private static func literalIntRange(_ expression: String) -> (Int, Int)? {
        let pieces = expression.components(separatedBy: "...")
        guard pieces.count == 2,
              let lower = literalInt(pieces[0]),
              let upper = literalInt(pieces[1]) else { return nil }
        return (lower, upper)
    }

    private static func literalDoubleRange(_ expression: String) -> (Double, Double)? {
        let pieces = expression.components(separatedBy: "...")
        guard pieces.count == 2 else { return nil }
        let lowerText = pieces[0].replacingOccurrences(of: "_", with: "")
        let upperText = pieces[1].replacingOccurrences(of: "_", with: "")
        guard let lower = Double(lowerText), let upper = Double(upperText) else { return nil }
        return (lower, upper)
    }

    private static func diagnoseMinMax(
        annotation: String,
        propertyName: String,
        min: String?,
        max: String?,
        identifier: TokenSyntax,
        context: some MacroExpansionContext
    ) {
        let minValue = literalInt(min)
        let maxValue = literalInt(max)
        if let minValue, minValue < 0 {
            context.diagnose(Diagnostic(node: Syntax(identifier), message: InvalidAnnotationDeclarationDiagnostic(annotation: annotation, propertyName: propertyName, detail: "minimum cannot be negative")))
        }
        if let maxValue, maxValue < 0 {
            context.diagnose(Diagnostic(node: Syntax(identifier), message: InvalidAnnotationDeclarationDiagnostic(annotation: annotation, propertyName: propertyName, detail: "maximum cannot be negative")))
        }
        if let minValue, let maxValue, minValue > maxValue {
            context.diagnose(Diagnostic(node: Syntax(identifier), message: InvalidAnnotationDeclarationDiagnostic(annotation: annotation, propertyName: propertyName, detail: "minimum cannot exceed maximum")))
        }
    }

    private static func dataOptions(on variable: VariableDeclSyntax) -> (min: String?, max: String?, modulo: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJData" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else {
                return (nil, nil, nil)
            }
            var min: String?
            var max: String?
            var modulo: String?
            for argument in arguments {
                switch argument.label?.text {
                case "min": min = argument.expression.trimmedDescription
                case "max": max = argument.expression.trimmedDescription
                case "modulo": modulo = argument.expression.trimmedDescription
                default: continue
                }
            }
            return (min, max, modulo)
        }
        return (nil, nil, nil)
    }

    private static func urlAllowedKinds(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJURL" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { return nil }
            for argument in arguments where argument.label?.text == "allowed" {
                return argument.expression.trimmedDescription
            }
            return nil
        }
        return nil
    }

    private static func uuidNonzero(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJUUID" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { return "true" }
            for argument in arguments where argument.label?.text == "nonzero" {
                return argument.expression.trimmedDescription
            }
            return "true"
        }
        return nil
    }

    private static func dateRange(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJDate" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { return nil }
            for argument in arguments where argument.label?.text == "range" {
                return argument.expression.trimmedDescription
            }
        }
        return nil
    }

    private static func colorAlpha(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "SBJColor" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { return nil }
            for argument in arguments where argument.label?.text == "alpha" {
                return argument.expression.trimmedDescription
            }
        }
        return nil
    }

    private static func propertyKind(for binding: PatternBindingSyntax, variable: VariableDeclSyntax) -> String {
        if let type = binding.typeAnnotation?.type.trimmedDescription {
            return propertyKind(forTypeDescription: type)
        }

        // A rule annotation may still provide a useful syntactic type category when
        // Swift inferred the stored property's type from its initializer. The
        // annotation is not required for participation; this is only metadata detail.
        let annotationKinds: [(String, String)] = [
            ("SBJString", ".text"), ("SBJInteger", ".integer"), ("SBJNumber", ".number"),
            ("SBJOptional", ".optional"), ("SBJArray", ".array"), ("SBJSet", ".set"),
            ("SBJDictionary", ".dictionary"), ("SBJURL", ".url"), ("SBJUUID", ".uuid"),
            ("SBJDate", ".date"), ("SBJData", ".data"), ("SBJColor", ".color")
        ]
        if let match = annotationKinds.first(where: { hasAttribute(named: $0.0, on: variable) }) {
            return match.1
        }

        if let initializer = binding.initializer?.value.trimmedDescription {
            if initializer == "true" || initializer == "false" { return ".bool" }
            if initializer.hasPrefix("URL(") { return ".url" }
            if initializer.hasPrefix("UUID(") { return ".uuid" }
            if initializer.hasPrefix("Date(") { return ".date" }
            if initializer.hasPrefix("Data(") { return ".data" }
            if initializer.hasPrefix("CodableColor(") { return ".color" }
            if initializer.hasPrefix("[") && initializer.hasSuffix("]") {
                return initializer.contains(":") ? ".dictionary" : ".array"
            }
            if initializer.first == "\"" { return ".text" }
        }
        return ".inferred"
    }

    private static func propertyKind(forTypeDescription type: String) -> String {
        let compact = type.replacingOccurrences(of: " ", with: "")
        if compact.hasSuffix("?") || compact.hasPrefix("Optional<") { return ".optional" }
        if compact.hasPrefix("Array<") { return ".array" }
        if compact.hasPrefix("Set<") { return ".set" }
        if compact.hasPrefix("Dictionary<") { return ".dictionary" }
        if compact.hasPrefix("[") && compact.hasSuffix("]") {
            return compact.contains(":") ? ".dictionary" : ".array"
        }
        switch compact {
        case "String", "Swift.String": return ".text"
        case "Bool", "Swift.Bool": return ".bool"
        case "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
             "Swift.Int", "Swift.Int8", "Swift.Int16", "Swift.Int32", "Swift.Int64", "Swift.UInt", "Swift.UInt8", "Swift.UInt16", "Swift.UInt32", "Swift.UInt64": return ".integer"
        case "Double", "Float", "CGFloat", "Decimal", "Swift.Double", "Swift.Float": return ".number"
        case "URL", "Foundation.URL": return ".url"
        case "UUID", "Foundation.UUID": return ".uuid"
        case "Date", "Foundation.Date": return ".date"
        case "Data", "Foundation.Data": return ".data"
        case "CodableColor": return ".color"
        default: return ".inferred"
        }
    }

    private static func keyPathPropertyName(from expression: String) -> String? {
        guard expression.hasPrefix("\\") else { return nil }
        let body = String(expression.dropFirst())
        guard let component = body.split(separator: ".").last, !component.isEmpty else {
            return nil
        }
        return String(component)
    }

    private static func hasAttribute(named name: String, on variable: VariableDeclSyntax) -> Bool {
        variable.attributes.contains { element in
            guard case .attribute(let attribute) = element else { return false }
            return attribute.attributeName.trimmedDescription == name
        }
    }

    private static func codingKeyNames(in declaration: StructDeclSyntax) -> Set<String>? {
        for member in declaration.memberBlock.members {
            guard let enumDecl = member.decl.as(EnumDeclSyntax.self),
                  enumDecl.name.text == "CodingKeys" else { continue }

            var names = Set<String>()
            for enumMember in enumDecl.memberBlock.members {
                guard let caseDecl = enumMember.decl.as(EnumCaseDeclSyntax.self) else { continue }
                for element in caseDecl.elements {
                    names.insert(element.name.text)
                }
            }
            return names
        }
        return nil
    }
}


private struct ConflictingArrayUniquenessDiagnostic: DiagnosticMessage {
    let name: String

    var message: String {
        "Array property '\(name)' cannot declare both unique: true and uniqueBy; choose one uniqueness rule"
    }

    var diagnosticID: MessageID {
        MessageID(domain: "SBJStructure.SBJArray", id: "conflicting-uniqueness")
    }

    var severity: DiagnosticSeverity { .error }
}

private struct InvalidAnnotationDeclarationDiagnostic: DiagnosticMessage {
    let annotation: String
    let propertyName: String
    let detail: String

    var message: String { "@\(annotation) on property '\(propertyName)' \(detail)" }
    var diagnosticID: MessageID { MessageID(domain: "SBJStructure.\(annotation)", id: "invalid-declaration") }
    var severity: DiagnosticSeverity { .error }
}

private enum SBJStructureMacroError: Error, CustomStringConvertible {
    case onlyStructsOrEnums

    var description: String {
        switch self {
        case .onlyStructsOrEnums:
            return "@SBJStructure can be applied only to structs or enums"
        }
    }
}
