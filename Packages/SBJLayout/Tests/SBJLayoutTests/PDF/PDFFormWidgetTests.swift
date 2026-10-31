#if !os(watchOS)
import Foundation
import PDFKit
import Testing
import UIKit
@testable import SBJLayout

@Suite("PDF AcroForm widgets")
struct PDFFormWidgetTests {
    @Test("Text, checkbox, and grouped radio annotations survive serialization")
    func fieldsRoundTrip() throws {
        let grid = Grid(vertFlow: .init(.fixed(240)), rows: .init(gap: 12)) {
            JCSTextField(name: "name", value: "Initial", minChars: 20)
            JCSCheckbox(name: "consent", checked: true)
            JCSRadioGroup(name: "choice", options: [
                .init("Yes", value: "yes"), .init("No", value: "no")
            ], selected: "no")
        }
        let result = PDFGenerator().form(grid)
        let document = try #require(PDFDocument(data: result.data))
        let annotations = (0..<document.pageCount).flatMap { document.page(at: $0)?.annotations ?? [] }
        #expect(annotations.count == 4)
        #expect(annotations.allSatisfy { $0.widgetFieldType == .text || $0.widgetFieldType == .button })
        #expect(Set(annotations.compactMap(\.fieldName)) == Set(["name", "consent", "choice"]))
        #expect(annotations.filter { $0.fieldName == "choice" }.count == 2)
        let field = try #require(annotations.first { $0.fieldName == "name" })
        #expect(field.widgetStringValue == "Initial")
        field.widgetStringValue = "Updated"
        let edited = try #require(document.dataRepresentation())
        let reopened = try #require(PDFDocument(data: edited))
        let after = (0..<reopened.pageCount).flatMap { reopened.page(at: $0)?.annotations ?? [] }
        #expect(after.first { $0.fieldName == "name" }?.widgetStringValue == "Updated")
        #expect(after.allSatisfy { $0.bounds.width > 0 && $0.bounds.height > 0 })
    }
}
#endif
