#if DEBUG
import Foundation
import Testing
@testable import SBJDataDefinition

struct SBJRecipeAnnotationCoverageTests {
    @Test func structuralAndPresentationMetadataStayDistinct() {
        let type = SBJStructureSampleModel.self
        #expect(type.propertyMetadata(for: \.name)?.constraints.contains(.stringRules(SBJStringRules(minLength: 1, maxLength: 80))) == true)
        #expect(type.propertyMetadata(for: \.servings)?.constraints.contains(.integerRules(SBJIntegerRules(range: 1...24))) == true)
        #expect(type.propertyMetadata(for: \.cookingStages)?.hints.contains(.fieldPresentation(SBJFieldPresentationValue(autoExpand: true))) == true)
        #expect(type.propertyMetadata(for: \.importSource)?.hints.contains(.fieldPresentation(SBJFieldPresentationValue(exclude: true))) == true)
        #expect(type.propertyMetadata(for: \.recipeCardTint)?.hints.contains(.colorPresentation(SBJColorPresentationValue(alpha: false))) == true)
        #expect(type.propertyMetadata(for: \.ingredients)?.kind == .array)
        #expect(type.propertyMetadata(for: \.tags)?.kind == .set)
        #expect(type.propertyMetadata(for: \.substitutions)?.kind == .dictionary)
        #expect(type.propertyMetadata(for: \.editorDisplayName) == nil)
        #expect(type.sbjPresentationProperties.contains { $0.name == "Editor Display Name" })
    }

    @Test func recipeCourseUsesTypeDefaultsAndPropertyOverrides() {
        let shared = SBJStructureSampleCourse.definitionTypeInfo
        let course = SBJStructureSampleModel.propertyInfo(for: \.course)
        let optional = SBJStructureSampleModel.propertyInfo(for: \.optionalCourse)

        #expect(shared.summary == "The meal category for a recipe.")
        #expect(course?.summary == "The course where this recipe is normally served.")
        #expect(course?.title == shared.title)
        #expect(course?.details == shared.details)
        #expect(course?.accessibilityHint == shared.accessibilityHint)
        #expect(optional?.title == shared.title)
        #expect(optional?.summary == shared.summary)
        #expect(optional?.details == shared.details)
        #expect(optional?.accessibilityHint == shared.accessibilityHint)
        #expect(SBJStructureSampleModel._propertyInfo(for: \.course) == nil)
        #expect(SBJStructureSampleModel._propertyInfo(for: \.optionalCourse) == nil)
    }

    @Test func associatedEnumStressCasesRemainRepresented() {
        let cases = SBJStructureSampleCookingInstruction.sbjAssociatedCases
        #expect(cases.map(\.sourceName) == ["adjustTemperature", "oven", "rest", "substitutions"])
        #expect(!cases.map(\.sourceName).contains("none"))
        #expect(SBJStructureSampleModel().noCookingInstruction == nil)
        #expect(cases[0].associatedValues.count == 1)
        #expect(cases[1].associatedValues.count == 3)
        #expect(cases[2].associatedValues.count == 3)
        #expect(cases[3].associatedValues.count == 3)
    }
}
#endif
