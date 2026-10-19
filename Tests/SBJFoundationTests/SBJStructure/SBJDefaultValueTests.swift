import Foundation
import Testing
@testable import SBJFoundation

private enum PlainChoice: String, Codable, CaseIterable {
    case first
    case second
}

private struct ExplicitDefault: Equatable, SBJDefaultValueCreatable {
    let value: Int

    static func sbjCreateDefaultValueIfPossible() -> Self? {
        .init(value: 42)
    }
}

private struct UnavailableDefault: SBJDefaultValueCreatable {
    static func sbjCreateDefaultValueIfPossible() -> Self? { nil }
}

@SBJEditable
private struct StructWithGeneratedDefault: Codable {
    var name = ""
    var count = 0
}

@SBJEditable
private struct StructWithoutGeneratedDefault: Codable {
    var name: String

    init(name: String) {
        self.name = name
    }
}

@SBJEditable
private enum AssociatedDefault: Codable {
    case unavailable(StructWithoutGeneratedDefault)
    case available(Int, label: String)
}

struct SBJDefaultValueTests {
    @Test func createsCommonScalarDefaultsWithoutEditor() {
        #expect(SBJDefaultValue.value(for: String.self) == "")
        #expect(SBJDefaultValue.value(for: Int.self) == 0)
        #expect(SBJDefaultValue.value(for: Bool.self) == false)
        #expect(SBJDefaultValue.value(for: Data.self) == Data())
    }

    @Test func usesExplicitContextFreeCreationProtocol() {
        #expect(SBJDefaultValue.value(for: ExplicitDefault.self) == .init(value: 42))
        #expect(SBJDefaultValue.value(for: UnavailableDefault.self) == nil)
    }

    @Test func usesStructuredGeneratedDefault() {
        let value = SBJDefaultValue.value(for: StructWithGeneratedDefault.self)
        #expect(value?.name == "")
        #expect(value?.count == 0)
        #expect(SBJDefaultValue.value(for: StructWithoutGeneratedDefault.self) == nil)
    }

    @Test func plainCaseIterableUsesFirstDeclaredCase() {
        #expect(SBJDefaultValue.value(for: PlainChoice.self) == .first)
    }

    @Test func associatedEnumCreationIsStructuralAndSkipsUncreatableCases() {
        let value = AssociatedDefault.sbjCreateDefaultValueIfPossible()
        guard case let .available(number, label) = value else {
            Issue.record("Expected the first fully creatable enum case")
            return
        }
        #expect(number == 0)
        #expect(label == "")

        let throughFactory = SBJDefaultValue.value(for: AssociatedDefault.self)
        guard case .available = throughFactory else {
            Issue.record("Expected associated enum creation through SBJDefaultValue")
            return
        }
    }
}
