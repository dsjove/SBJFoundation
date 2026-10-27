import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// A generation layer augments the structural declarations without changing them.
/// Layers are ordered and may be composed by higher-level macro packages.
/// No editor runtime types are referenced by the structural generator.
public protocol SBJMacroGenerationLayer {
    func additionalConformances(isStruct: Bool, hasEnumPayload: Bool) -> [String]
    func nonStructuralProperty(name: String) -> String?
    func storedProperty(name: String, disclosure: String) -> String?
    func structMembers(access: String, fields: [String]) -> [DeclSyntax]
    func enumMembers(access: String, cases: [SBJStructureGeneration.EnumCaseInfo]) -> [DeclSyntax]
}

public extension SBJMacroGenerationLayer {
    func additionalConformances(isStruct: Bool, hasEnumPayload: Bool) -> [String] { [] }
    func nonStructuralProperty(name: String) -> String? { nil }
    func storedProperty(name: String, disclosure: String) -> String? { nil }
    func structMembers(access: String, fields: [String]) -> [DeclSyntax] { [] }
    func enumMembers(access: String, cases: [SBJStructureGeneration.EnumCaseInfo]) -> [DeclSyntax] { [] }
}

/// Structural generation shared by structural and presentation-aware macros.
public enum SBJStructureGeneration {
    private static func hasBothAnnotations(_ declaration: some DeclGroupSyntax) -> Bool {
        let attributes: AttributeListSyntax
        if let declaration = declaration.as(StructDeclSyntax.self) {
            attributes = declaration.attributes
        } else if let declaration = declaration.as(EnumDeclSyntax.self) {
            attributes = declaration.attributes
        } else {
            return false
        }
        let names = Set(attributes.compactMap { element -> String? in
            element.as(AttributeSyntax.self)?.attributeName.trimmedDescription
        })
        return names.contains("SBJStructure") && names.contains("SBJEditable")
    }

    public static func members(
        of declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext,
        layers: [any SBJMacroGenerationLayer] = []
    ) throws -> [DeclSyntax] {
        if hasBothAnnotations(declaration) {
            throw SBJStructureMacroError.conflictingAnnotations
        }
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return structMembers(for: structDecl, in: context, layers: layers)
        }
        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return enumMembers(for: enumDecl, in: context, layers: layers)
        }
        throw SBJStructureMacroError.onlyStructsOrEnums
    }

    public static func extensions(
        of declaration: some DeclGroupSyntax,
        type: some TypeSyntaxProtocol,
        layers: [any SBJMacroGenerationLayer] = []
    ) throws -> [ExtensionDeclSyntax] {
        if hasBothAnnotations(declaration) {
            return [] // The member expansion reports the conflict.
        }
        let isStruct = declaration.is(StructDeclSyntax.self)
        guard isStruct || declaration.is(EnumDeclSyntax.self) else {
            throw SBJStructureMacroError.onlyStructsOrEnums
        }
        let hasPayload = !isStruct && enumCases(in: declaration.cast(EnumDeclSyntax.self)).contains { !$0.parameters.isEmpty }
        var conformances = isStruct ? ["SBJMutableStructure"] :
            (hasPayload ? ["SBJEnumCaseIdentifiable", "SBJStructuredEnum", "SBJDefaultValueCreatable"] : ["SBJEnumCaseIdentifiable"])
        for layer in layers {
            conformances.append(contentsOf: layer.additionalConformances(isStruct: isStruct, hasEnumPayload: hasPayload))
        }
        let conformance = conformances.joined(separator: ", ")

        let extensionDecl: DeclSyntax = """
        extension \(type.trimmed): \(raw: conformance) {}
        """
        return [extensionDecl.cast(ExtensionDeclSyntax.self)]
    }

    // MARK: - Structs

    private static func structMembers(
        for structDecl: StructDeclSyntax,
        in context: some MacroExpansionContext,
        layers: [any SBJMacroGenerationLayer]
    ) -> [DeclSyntax] {
        let codedNames = codingKeyNames(in: structDecl)
        // Named static declarations (`nameInfo`, etc.) provide zero-boilerplate
        // metadata. The underscored implementation remains callable by explicit
        // static propertyInfo(for:) overrides, including overrides in extensions.
        let conventionalInfoNames: Set<String> = Set(structDecl.memberBlock.members.compactMap { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }),
                  let binding = variable.bindings.first,
                  let id = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  id.hasSuffix("Info") else { return nil }
            return String(id.dropLast(4))
        })

        let access = effectiveAccessPrefix(modifiers: structDecl.modifiers, in: context)

        var propertyEntries: [String] = []
        var editableEntries: [String] = []
        var writableCodedNames: [String] = []
        var presentationEntries: [String] = []
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
                // structure. @SBJPresentationProperty opts one into presentation
                // generation only. It does not become structural metadata.
                if let accessorBlock = binding.accessorBlock {
                    let isStoredWithObservers: Bool
                    switch accessorBlock.accessors {
                    case .accessors(let list):
                        isStoredWithObservers = list.allSatisfy {
                            $0.accessorSpecifier.text == "willSet" || $0.accessorSpecifier.text == "didSet"
                        }
                    case .getter:
                        isStoredWithObservers = false
                    }
                    if !isStoredWithObservers {
                        if hasAttribute(named: "SBJPresentationProperty", on: variable) {
                            presentationEntries.append(
                                "SBJMutableProperty<Self>(nonStructuralName: \"\(name)\".uncamelCased, \\.\(name))"
                            )
                        }
                        if (hasAttribute(named: "SBJPresentationProperty", on: variable) || hasAttribute(named: "SBJEditorProperty", on: variable)) {
                            for layer in layers {
                                if let field = layer.nonStructuralProperty(name: name) {
                                    editableEntries.append(
                                        "SBJMutableProperty<Self>(nonStructuralName: \"\(name)\".uncamelCased, \\.\(name))"
                                    )
                                    entries.append(field)
                                }
                            }
                        }
                        continue
                    }
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
                // presentation eligibility. Read-only and excluded properties
                // remain part of the declared model and are validated when a
                // consumer explicitly invokes the invariant.
                contentMembers.append(name)
                let arrayOptions = arrayOptions(on: variable)
                let arrayTitle = (editorTitle(on: variable, annotation: "SBJPresentationArray") ?? editorTitle(on: variable, annotation: "SBJEditorArray"))
                let setOptions = setOptions(on: variable)
                let setTitle = (editorTitle(on: variable, annotation: "SBJPresentationSet") ?? editorTitle(on: variable, annotation: "SBJEditorSet"))
                if let itemTitleKey = arrayTitle {
                    invariantStatements.append("try SBJInvariantCheck.validate(\(name), at: keyPath.appending(\\Self.\(name)), itemTitleKey: \(swiftStringLiteral(itemTitleKey)))")
                } else if let itemTitleKey = setTitle {
                    invariantStatements.append("try SBJInvariantCheck.validate(\(name), at: keyPath.appending(\\Self.\(name)), itemTitleKey: \(swiftStringLiteral(itemTitleKey)))")
                } else {
                    invariantStatements.append("try SBJInvariantCheck.validate(\(name), at: keyPath.appending(\\Self.\(name)))")
                }

                let textConstraints = editorTextConstraints(on: variable)
                if let textStyle = textStyle(on: variable) {
                    hintMetadata.append(".textStyle(\(textStyle))")
                }
                if let disclosure = editorDisclosure(on: variable) {
                    hintMetadata.append(".presentationDisclosure(\(disclosure))")
                }
                if hasAttribute(named: "SBJPresentationExclude", on: variable) {
                    hintMetadata.append(".presentationExcluded")
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
                if let unitMutable = unitValueMutable(on: variable) {
                    constraintMetadata.append(".unitMutable(\(unitMutable))")
                }
                if let defaultUnit = unitValueDefault(on: variable) {
                    constraintMetadata.append(".defaultUnit(SBJDefaultUnit(\(defaultUnit)))")
                    if unitValueMutable(on: variable) == "false" {
                        invariantStatements.append("try SBJInvariantCheck.requireUnit(\(name), \(defaultUnit), at: keyPath.appending(\\Self.\(name)))")
                    }
                }
                if let unitSystem = unitValueSystem(on: variable) {
                    constraintMetadata.append(".unitSystem(\(unitSystem))")
                    invariantStatements.append("try SBJInvariantCheck.requireUnitSystem(\(name), \(unitSystem), at: keyPath.appending(\\Self.\(name)))")
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

                if let colorAlpha = colorAlpha(on: variable) {
                    hintMetadata.append(".colorSupportsAlpha(\(colorAlpha))")
                }

                if let reorderable = arrayOptions.reorderable {
                    constraintMetadata.append(".reorderable(\(reorderable))")
                }
                if let title = arrayTitle ?? setTitle {
                    hintMetadata.append(".itemTitle(\"\(title)\")")
                }

                let constraints = constraintMetadata.joined(separator: ", ")
                let hints = hintMetadata.joined(separator: ", ")
                propertyEntries.append(
                    "SBJPropertyMetadata<Self>(sourceName: \"\(name)\", displayName: \"\(name)\".uncamelCased, keyPath: \\Self.\(name), kind: \(kind), constraints: [\(constraints)], hints: [\(hints)], info: Self.propertyInfo(for: \\Self.\(name)))"
                )

                if variable.bindingSpecifier.tokenKind != .keyword(.let) {
                    writableCodedNames.append(name)
                }

                // Writable presentation eligibility is distinct from structural metadata.
                if (hasAttribute(named: "SBJPresentationExclude", on: variable) || hasAttribute(named: "SBJEditorExclude", on: variable)) { continue }

                // Immutable stored properties remain part of structure metadata,
                // export, content checks, and invariants, but are simply not editable.
                if variable.bindingSpecifier.tokenKind == .keyword(.let) { continue }

                editableEntries.append(
                    "SBJMutableProperty<Self>(name: \"\(name)\".uncamelCased, \\.\(name))"
                )
                for layer in layers {
                    if let field = layer.storedProperty(name: name, disclosure: editorDisclosure(on: variable) ?? ".closed") {
                        entries.append(field)
                    }
                }
            }
        }

        let hasExplicitGeneratedInfo = structDecl.memberBlock.members.contains { member in
            guard let method = member.decl.as(FunctionDeclSyntax.self) else { return false }
            return method.name.text == "_propertyInfo"
        }
        let conventionalEntries = structDecl.memberBlock.members.compactMap { member -> String? in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  !variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }) else { return nil }
            return variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
        }.filter { conventionalInfoNames.contains($0) && (codedNames == nil || codedNames!.contains($0)) }

        let propertyBody = propertyEntries.joined(separator: ",\n")
        let editableBody = editableEntries.joined(separator: ",\n")
        let writableCodedBody = writableCodedNames.map { swiftStringLiteral($0) }.joined(separator: ", ")
        let presentationBody = presentationEntries.joined(separator: ",\n")
        var result: [DeclSyntax] = []
        if !hasExplicitGeneratedInfo {
            let generatedCases = conventionalEntries.map { name in
                "case \\Self.\(name): return Self.\(name)Info"
            }.joined(separator: "\n                ")
            result.append(DeclSyntax(stringLiteral: """
            \(access)static func _propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
                switch keyPath as AnyKeyPath {
                \(generatedCases)
                default: return nil
                }
            }
            """))
        }
        result += [
            DeclSyntax(stringLiteral: """
            \(access)static var sbjSwiftWritablePropertyNames: Set<String> {
                [\(writableCodedBody)]
            }
            """),
            DeclSyntax(stringLiteral: """
            \(access)static var sbjProperties: [SBJPropertyMetadata<Self>] {
                [
                    \(propertyBody)
                ]
            }
            """),
            DeclSyntax(stringLiteral: """
            \(access)static var sbjMutableProperties: [SBJMutableProperty<Self>] {
                [
                    \(editableBody)
                ]
            }
            """),
            DeclSyntax(stringLiteral: """
            \(access)static var sbjPresentationProperties: [SBJMutableProperty<Self>] {
                [
                    \(presentationBody)
                ]
            }
            """),
        ]
        for layer in layers {
            result.append(contentsOf: layer.structMembers(access: access, fields: entries))
        }

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

        // Source-export selection is independent of default construction. An explicit
        // @SBJDesignatedInit remains the override when multiple complete signatures exist.
        if let inferred = inferredSwiftInitializerParameters(for: structDecl, properties: contentMembers, access: access, context: context) {
            result.append(DeclSyntax(stringLiteral: inferred))
        }

        if !hasExplicitDefaultValue {
            if let generated = designatedDefaultFactory(for: structDecl, access: access) {
                result.append(DeclSyntax(stringLiteral: generated))
            } else if canInitializeWithoutArguments(structDecl) {
                result.append(
                    DeclSyntax(stringLiteral: """
                    \(access)static func sbjDefaultValue() -> Self? {
                        .init()
                    }
                    """)
                )
            }
        }

        return result
    }

    /// Infer export metadata only when exactly one initializer covers all coded
    /// stored properties by internal or external parameter names. Do not guess
    /// when overloaded signatures are equally complete.
    private static func inferredSwiftInitializerParameters(
        for declaration: StructDeclSyntax,
        properties: [String],
        access: String,
        context: some MacroExpansionContext
    ) -> String? {
        let initializers = declaration.memberBlock.members.compactMap { $0.decl.as(InitializerDeclSyntax.self) }
        // A peer macro on the designated initializer already emits this member.
        if initializers.contains(where: { initializer in
            initializer.attributes.contains(where: { element in
                element.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "SBJDesignatedInit"
            })
        }) { return nil }
        let names = Set(properties)
        let candidates = initializers.compactMap { initializer -> [String]? in
            guard initializer.optionalMark == nil,
                  initializer.signature.effectSpecifiers == nil else { return nil }
            let parameters = initializer.signature.parameterClause.parameters
            guard parameters.count == properties.count else { return nil }
            var matched = Set<String>()
            var result: [String] = []
            for parameter in parameters {
                let external = parameter.firstName.text
                let internalName = parameter.secondName?.text ?? external
                let property: String
                if names.contains(internalName) { property = internalName }
                else if external != "_" && names.contains(external) { property = external }
                else { return nil }
                guard matched.insert(property).inserted else { return nil }
                let label = external == "_" ? "nil" : swiftStringLiteral(external)
                let defaultArg = parameter.defaultValue.map {
                    ", defaultExpression: " + swiftStringLiteral($0.value.trimmedDescription)
                } ?? ""
                result.append(".init(propertyName: \(swiftStringLiteral(property)), label: \(label)\(defaultArg))")
            }
            return matched == names ? result : nil
        }
        if candidates.count > 1 {
            context.diagnose(Diagnostic(
                node: Syntax(declaration.name),
                message: AmbiguousReconstructionInitializerDiagnostic(count: candidates.count)
            ))
        }
        // With explicit initializers, never pretend Swift's memberwise initializer
        // exists. An empty mapping requests a Codable reconstruction fallback.
        if !initializers.isEmpty && candidates.count != 1 {
            return """
            \(access)static var sbjSwiftInitializerParameters: [SBJSwiftInitializerParameter] { [] }
            """
        }
        guard candidates.count == 1, let parameters = candidates.first else { return nil }
        return """
        \(access)static var sbjSwiftInitializerParameters: [SBJSwiftInitializerParameter] {
            [\(parameters.joined(separator: ",\n"))]
        }
        """
    }

    /// Synthesize a context-free factory from the source-level designated initializer.
    /// Defaulted arguments are intentionally omitted: Swift evaluates their declared
    /// defaults, while required arguments are resolved through SBJDefaultValue.
    private static func designatedDefaultFactory(for structDecl: StructDeclSyntax, access: String) -> String? {
        let designated = structDecl.memberBlock.members.compactMap {
            $0.decl.as(InitializerDeclSyntax.self)
        }.filter { initializer in
            initializer.attributes.contains { element in
                guard case .attribute(let attribute) = element else { return false }
                return attribute.attributeName.trimmedDescription == "SBJDesignatedInit"
            }
        }
        guard designated.count == 1, let initializer = designated.first else { return nil }
        let signature = initializer.signature.trimmedDescription
        guard !signature.contains("async"), !signature.contains("throws"),
              !signature.contains("rethrows"), initializer.optionalMark == nil else { return nil }

        var declarations: [String] = []
        var arguments: [String] = []
        for (index, parameter) in initializer.signature.parameterClause.parameters.enumerated() {
            if parameter.defaultValue != nil { continue }
            let type = parameter.type.trimmedDescription
            // Inout, variadic and function arguments are not safely constructible
            // through the context-free factory.
            if type.hasPrefix("inout ") || parameter.ellipsis != nil { return nil }
            let local = "sbjArg\(index)"
            declarations.append("guard let \(local): \(type) = SBJDefaultValue.value(for: \(type).self) else { return nil }")
            let external = parameter.firstName.text
            arguments.append(external == "_" ? local : "\(external): \(local)")
        }
        let body = (declarations + ["return .init(\(arguments.joined(separator: ", ")))"]).joined(separator: "\n")
        return """
        \(access)static func sbjDefaultValue() -> Self? {
            \(body)
        }
        """
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

    public struct EnumParameter {
        public let type: String
        public let fieldNameExpression: String
        public let constructorLabel: String?
        public let variableName: String
    }

    public struct EnumCaseInfo {
        public let caseName: String
        public let displayNameExpression: String
        public let parameters: [EnumParameter]
    }

    private static func enumMembers(
        for enumDecl: EnumDeclSyntax,
        in context: some MacroExpansionContext,
        layers: [any SBJMacroGenerationLayer]
    ) -> [DeclSyntax] {
        let access = effectiveAccessPrefix(modifiers: enumDecl.modifiers, in: context)
        let cases = enumCases(in: enumDecl)
        let hasExplicitStructuralEquals = enumDecl.memberBlock.members.contains { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self) else { return false }
            return function.name.text == "sbjStructuralEquals"
        }

        let hasPayload = cases.contains { !$0.parameters.isEmpty }
        let failableCreatorBody = enumFailableCreatorBody(for: cases)
        let sourceCaseNames = cases.map { swiftStringLiteral($0.caseName) }.joined(separator: ", ")
        let sourceCaseNameSwitch = cases.map { info in
            "case \(casePattern(info)): \(swiftStringLiteral(info.caseName))"
        }.joined(separator: "\n        ")

        // Case presentation names come from `caseNameInfo` members in a metadata
        // extension. The protocol's default lookup returns nil when none exists.
        // Metadata may also live beside the enum's cases as conventional
        // `static let caseNameInfo` members. Extension metadata is synthesized
        // independently by @SBJPropertyInfoEnum.
        let infoNames = Set(enumDecl.memberBlock.members.compactMap { member -> String? in
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }),
                  let id = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  id.hasSuffix("Info") else { return nil }
            return String(id.dropLast(4))
        })
        let namedCaseInfo = cases.filter { infoNames.contains($0.caseName) }
        let infoSwitch = namedCaseInfo.map { info in
            "case \(swiftStringLiteral(info.caseName)): return Self.\(info.caseName)Info"
        }.joined(separator: "\n            ")

        var result: [DeclSyntax] = [
            DeclSyntax(stringLiteral: """
            public static var sbjCaseNames: [String] {
                [\(sourceCaseNames)]
            }
            """),
            DeclSyntax(stringLiteral: """
            public var sbjCaseName: String {
                switch self {
                \(sourceCaseNameSwitch)
                }
            }
            """),
        ]

        if !namedCaseInfo.isEmpty {
            result.append(DeclSyntax(stringLiteral: """
            public static func sbjCaseInfo(for caseName: String) -> SBJPropertyInfo? {
                switch caseName {
                \(infoSwitch)
                default: return nil
                }
            }
            """))
        }

        // Plain enums supply exact case names for source export but use the
        // generic CaseIterable & Hashable editor, without associated-value APIs.
        guard hasPayload else { return result }

        let associatedCases = cases.map { info in
            let pattern = casePattern(info)
            let creator = enumOptionalCreatorBody(for: info)
            let payloads = info.parameters.enumerated().map { index, parameter in
                let names = info.parameters.indices.map { $0 == index ? info.parameters[$0].variableName : "_" }
                let getPattern = caseLetPattern(info, names: names)
                let otherNames = info.parameters.indices.map { $0 == index ? "_" : info.parameters[$0].variableName }
                let setPattern = caseLetPattern(info, names: otherNames)
                let caseKeyword = otherNames.contains(where: { $0 != "_" }) ? "case let" : "case"
                var replacement = info.parameters.map(\.variableName)
                replacement[index] = "newValue"
                let constructed = caseConstruction(info, values: replacement)
                return """
                SBJAssociatedValue<Self>(
                    name: \(parameter.fieldNameExpression),
                    get: { root in
                        guard case let \(getPattern) = root else {
                            preconditionFailure("Associated value accessed for the wrong enum case")
                        }
                        return \(parameter.variableName)
                    },
                    set: { root, newValue in
                        guard \(caseKeyword) \(setPattern) = root else { return }
                        root = \(constructed)
                    }
                )
                """
            }.joined(separator: ",\n")
            return """
            SBJAssociatedCase<Self>(
                sourceName: \(swiftStringLiteral(info.caseName)),
                matches: { value in
                    if case \(pattern) = value { return true }
                    return false
                },
                makeDefault: {
                    \(creator)
                },
                associatedValues: [
                    \(payloads)
                ]
            )
            """
        }.joined(separator: ",\n")
        result.append(DeclSyntax(stringLiteral: """
            \(access)static var sbjAssociatedCases: [SBJAssociatedCase<Self>] {
                [
                    \(associatedCases)
                ]
            }
            """))
        for layer in layers {
            result.append(contentsOf: layer.enumMembers(access: access, cases: cases))
        }
        result.append(DeclSyntax(stringLiteral: """
            \(access)static func sbjCreateDefaultValueIfPossible() -> Self? {
                \(failableCreatorBody)
            }
            """))

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

    public static func enumOptionalCreatorBody(for info: EnumCaseInfo) -> String {
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

    public static func casePattern(_ info: EnumCaseInfo) -> String {
        guard !info.parameters.isEmpty else { return ".\(info.caseName)" }
        return ".\(info.caseName)(\(Array(repeating: "_", count: info.parameters.count).joined(separator: ", ")))"
    }

    public static func caseLetPattern(_ info: EnumCaseInfo, names: [String]) -> String {
        guard !names.isEmpty else { return ".\(info.caseName)" }
        return ".\(info.caseName)(\(names.joined(separator: ", ")))"
    }

    public static func caseConstruction(_ info: EnumCaseInfo, values: [String]) -> String {
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



    private static func editorDisclosure(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element,
                  (attribute.attributeName.trimmedDescription == "SBJPresentationDisclosure" || attribute.attributeName.trimmedDescription == "SBJEditorDisclosure"),
                  let arguments = attribute.arguments,
                  case .argumentList(let list) = arguments,
                  let first = list.first else { continue }
            let mode = first.expression.trimmedDescription
            if mode == ".closed" || mode == ".autoOpen" || mode == ".alwaysOpen" { return mode }
        }
        return nil
    }

    private static func textStyle(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard (attribute.attributeName.trimmedDescription == "SBJPresentationString" || attribute.attributeName.trimmedDescription == "SBJEditorString") else { continue }
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
            guard (attribute.attributeName.trimmedDescription == "SBJPresentationString" || attribute.attributeName.trimmedDescription == "SBJEditorString") else { continue }
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

    private static func unitValueMutable(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element,
                  attribute.attributeName.trimmedDescription == "SBJUnitValue" else { continue }
            guard let raw = attribute.arguments,
                  case .argumentList(let arguments) = raw else { return "true" }
            return arguments.first(where: { $0.label?.text == "unitMutable" })?.expression.trimmedDescription ?? "true"
        }
        return nil
    }

    private static func unitValueDefault(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element,
                  attribute.attributeName.trimmedDescription == "SBJUnitValue",
                  let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { continue }
            return arguments.first(where: { $0.label?.text == "defaultUnit" })?.expression.trimmedDescription
        }
        return nil
    }

    private static func unitValueSystem(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element,
                  attribute.attributeName.trimmedDescription == "SBJUnitValue",
                  let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { continue }
            return arguments.first(where: { $0.label?.text == "unitSystem" })?.expression.trimmedDescription
        }
        return nil
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

    private static func editorTitle(on variable: VariableDeclSyntax, annotation: String) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element,
                  attribute.attributeName.trimmedDescription == annotation,
                  let raw = attribute.arguments,
                  case .argumentList(let args) = raw,
                  let argument = args.first(where: { $0.label?.text == "title" }) else { continue }
            let expression = argument.expression.trimmedDescription
            return expression == "nil" ? nil : keyPathPropertyName(from: expression)
        }
        return nil
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


private struct AmbiguousReconstructionInitializerDiagnostic: DiagnosticMessage {
    let count: Int
    var message: String {
        "Found \(count) complete reconstruction initializers; annotate the intended initializer with @SBJDesignatedInit or use Codable reconstruction"
    }
    var diagnosticID: MessageID {
        MessageID(domain: "SBJStructure.Initialization", id: "ambiguous-reconstruction")
    }
    var severity: DiagnosticSeverity { .warning }
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
    case conflictingAnnotations

    var description: String {
        switch self {
        case .onlyStructsOrEnums:
            return "@SBJStructure and @SBJEditable can be applied only to structs or enums"
        case .conflictingAnnotations:
            return "Use either @SBJStructure or @SBJEditable, not both"
        }
    }
}
