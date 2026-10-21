import Foundation
import Testing
@testable import SBJLocalization

struct DataHexFormattingTests {
    @Test func hexFormattingPreservesBytesAndPadding() {
        let data = Data([0x00, 0x10, 0xAB, 0xFF])
        #expect(data.sbjHexFormat() == "00 10 AB FF")
    }
}
