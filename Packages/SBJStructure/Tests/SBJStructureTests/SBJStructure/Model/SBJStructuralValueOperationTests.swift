import Foundation
import Testing
import SBJStructure

@Suite("Typed scalar operations")
struct SBJStructuralValueOperationTests {
    @Test func integerArithmeticIsChecked() throws {
        let newGold = try SBJStructuralValueMutation.applying(.increase(200), to: 678) as! Int
        #expect(newGold == 878)
        #expect(throws: SBJStructuralValueOperationError.overflow) {
            try SBJStructuralValueMutation.applying(.increase(1), to: Int.max)
        }
        #expect(throws: SBJStructuralValueOperationError.overflow) {
            try SBJStructuralValueMutation.applying(.decrease(UInt8(1)), to: UInt8(0))
        }
        #expect(throws: SBJStructuralValueOperationError.divisionByZero) {
            try SBJStructuralValueMutation.applying(.divide(0), to: 678)
        }
        #expect(throws: SBJStructuralValueOperationError.overflow) {
            try SBJStructuralValueMutation.applying(.divide(-1), to: Int.min)
        }
        #expect(throws: SBJStructuralValueOperationError.typeMismatch) {
            try SBJStructuralValueMutation.applying(.increase(2.5), to: 678)
        }
    }

    @Test func floatingPointRejectsNonfiniteResults() throws {
        let result = try SBJStructuralValueMutation.applying(.multiply(1.5), to: 4.0) as! Double
        #expect(result == 6)
        #expect(throws: SBJStructuralValueOperationError.nonfiniteValue) {
            try SBJStructuralValueMutation.applying(.multiply(2.0), to: Double.greatestFiniteMagnitude)
        }
        #expect(throws: SBJStructuralValueOperationError.divisionByZero) {
            try SBJStructuralValueMutation.applying(.divide(0.0), to: 12.0)
        }
    }

    @Test func booleanAndTextOperations() throws {
        #expect(try SBJStructuralValueMutation.applying(.toggle, to: false) as! Bool)
        let result = try SBJStructuralValueMutation.applying(.replaceText("blue", with: "red"), to: "blue dragon") as! String
        #expect(result == "red dragon")
        #expect(throws: SBJStructuralValueOperationError.missingText) {
            try SBJStructuralValueMutation.applying(.removeText("missing"), to: "blue dragon")
        }
    }

    @Test func dateShiftAndCapabilities() throws {
        let date = Date(timeIntervalSince1970: 10)
        let later = try SBJStructuralValueMutation.applying(.advanceDate(20), to: date) as! Date
        #expect(later.timeIntervalSince1970 == 30)
        #expect(SBJStructuralValueMutation.supportedOperations(for: 678).contains(.increase))
        #expect(!SBJStructuralValueMutation.supportedOperations(for: [1, 2]).contains(.increase))
        #expect(SBJValueOperationNomenclature.matching("increment") == [.increase])
        #expect(SBJValueOperationNomenclature.matching("add").isEmpty)
        #expect(throws: SBJStructuralValueOperationError.unsupportedOperation) {
            try SBJStructuralValueMutation.applying(.increase(5), to: [1, 2])
        }
    }
}
