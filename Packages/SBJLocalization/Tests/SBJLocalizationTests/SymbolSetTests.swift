import Foundation
import Testing
@testable import SBJLocalization

private enum TestSymbols: SBJSymbolSet {
    static let all: [String: SBJSymbol] = ["existing": .system("checkmark")]
}

@Suite("SBJ symbol vocabulary")
struct SymbolSetTests {
    @Test func unknownSymbolsUseVisibleFallback() {
        let fallback = SBJSymbol.system("exclamationmark.questionmark")
        #expect(TestSymbols.missing == fallback)
        #expect(TestSymbols.notDefined == fallback)
        #expect(TestSymbols.existing == .system("checkmark"))
    }

    @Test func symbolCasesReportEmptyIdentifiers() {
        #expect(SBJSymbol.system("").isEmpty)
        #expect(SBJSymbol.asset("").isEmpty)
        #expect(SBJSymbol.bundleImage(name: "").isEmpty)
        #expect(!SBJSymbol.system("star").isEmpty)
        #expect(!SBJSymbol.asset("custom").isEmpty)
        #expect(!SBJSymbol.bundleImage(name: "picture", extension: "png").isEmpty)
    }

    @Test func bundledImageURLUsesSuppliedBundleAndReturnsNilForMissingFile() {
        let symbol = SBJSymbol.bundleImage(name: "absent-test-image-92813", extension: "png", bundle: .main)
        #expect(symbol.bundledImageURL == nil)
        #expect(SBJSymbol.system("star").bundledImageURL == nil)
        #expect(SBJSymbol.asset("star").bundledImageURL == nil)
    }
}
