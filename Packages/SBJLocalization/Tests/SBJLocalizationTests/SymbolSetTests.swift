import Testing
@testable import SBJLocalization

private enum TestSymbols: SBJSymbolSet {
    static let all: [String: SBJSymbol] = ["existing": .system("checkmark")]
}

@Test func unknownSymbolUsesVisibleFallback() {
    #expect(TestSymbols.missing == .missing)
    #expect(TestSymbols.notDefined == .missing)
    #expect(TestSymbols.existing == .system("checkmark"))
}
