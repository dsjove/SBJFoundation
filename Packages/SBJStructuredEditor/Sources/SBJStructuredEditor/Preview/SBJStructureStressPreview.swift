import SBJUIVocabulary
import SBJUnits
#if !os(tvOS) && !os(watchOS)
#if DEBUG
import Foundation
import SwiftUI

/// A deliberately broad test bed for recursive editing and enum-case switching.
/// Separate from the canonical recipe fixture so its existing tests remain stable.
@SBJEditable
enum SBJStructureStressChoice: Codable {
    case unspecified

    case adjustment(Int)

    case condition(threshold: Double, enabled: Bool, explanation: String)

    case schedule(start: Date, end: Date, comment: String?)

    case collection(values: [Int], names: [String: String], flags: Set<String>)
}

@SBJPropertyInfoEnum
extension SBJStructureStressChoice {
    static let unspecifiedInfo = SBJPropertyInfo(title: "Not specified", summary: "A case with no associated values.")
    static let adjustmentInfo = SBJPropertyInfo(title: "Numeric adjustment", summary: "A single unlabeled numeric payload.")
    static let conditionInfo = SBJPropertyInfo(title: "Conditional rule", summary: "Multiple labeled values of different types.")
    static let scheduleInfo = SBJPropertyInfo(title: "Scheduled interval", summary: "Two dates and an optional comment.")
    static let collectionInfo = SBJPropertyInfo(title: "Complex collection", summary: "Nested collection payloads with optional elements.")
}

@SBJEditable
enum SBJStructureStressNested: Codable {
    case absent
    case direct(SBJStructureStressChoice)
    case labeled(primary: SBJStructureStressChoice, secondary: SBJStructureStressChoice?)
}

@SBJEditable
struct SBJStructureStressSection: Codable {
    var title = "Nested structure"
    var choice: SBJStructureStressChoice = .adjustment(3)
    var optionalChoice: SBJStructureStressChoice? = .condition(
        threshold: 2.5, enabled: false, explanation: "Optional nested payload"
    )
}

@SBJEditable
struct SBJStructureStressModel: Codable {
    // Same case across several positions to reveal incorrect binding reuse.
    var noPayload: SBJStructureStressChoice = .unspecified
    var singleUnlabeled: SBJStructureStressChoice = .adjustment(-2)
    var multipleLabeled: SBJStructureStressChoice = .condition(
        threshold: 12.5, enabled: true, explanation: "Multiline description\nSecond line"
    )
    var optionalPayload: SBJStructureStressChoice = .schedule(
        start: Date(timeIntervalSince1970: 1_700_000_000),
        end: Date(timeIntervalSince1970: 1_700_086_400),
        comment: nil
    )
    var collectionPayload: SBJStructureStressChoice = .collection(
        values: [1, 2, 3], names: ["a": "Alpha", "b": "Beta"], flags: ["On", "Checked"]
    )

    // The generic CaseIterable & Hashable editor (no @SBJEditable annotation).
    var plainEnum: SBJStructureSampleCourse = .lunch
    var optionalPlainEnum: SBJStructureSampleCourse? = nil

    // Optional enum, array of enums, dictionary and nested payload enum.
    var optionalEnum: SBJStructureStressChoice? = .adjustment(7)
    var nilEnum: SBJStructureStressChoice? = nil
    var enumArray: [SBJStructureStressChoice] = [.unspecified, .adjustment(4)]
    var enumDictionary: [String: SBJStructureStressChoice] = ["first": .adjustment(1)]
    var nestedEnum: SBJStructureStressNested = .labeled(
        primary: .adjustment(9), secondary: .unspecified
    )
    var nestedStruct: SBJStructureStressSection = .init()
    var nestedStructArray: [SBJStructureStressSection] = [.init(), .init()]

    // Generic editing of scalar, optional, collection and recursive values.
    var emptyText = ""
    var multilineText = "One line\nAnother line"
    var optionalText: String? = nil
    var optionalNumber: Int? = 5
    var boolFlag = true
    var decimal: Decimal = 4.25
    var tags: Set<String> = ["alpha", "beta"]
    var notes: [String: String] = ["a": "First", "b": "Second"]
}

@MainActor
private struct SBJStructureStressPreviewHost: View {
    @State private var model = SBJStructureStressModel()
    @State private var editorState = SBJEditorPresentationModel()

    var body: some View {
        VStack(alignment: .leading) {
            Text("Structured Editor — Complex Cases")
                .font(.headline)
            Text("Try switching every enum case, editing payloads, adding/removing collection items, and toggling nil values.")
                .font(.caption)
                .foregroundStyle(.secondary)
            SBJEditorScrollView(presentationModel: editorState) {
                SBJEditorView(value: $model, presentationModel: editorState)
                    .padding(.vertical, 8)
            }
        }
        .padding()
    }
}

#Preview("SBJStructure — Complex Values") {
    SBJStructureStressPreviewHost()
        .frame(minWidth: 760, minHeight: 1100)
}

#Preview("SBJStructure — Complex Narrow") {
    SBJStructureStressPreviewHost()
        .frame(width: 390, height: 900)
}
#endif
#endif
