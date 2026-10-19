import SBJDataDefinitionMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import SBJStructureMacroSupport

final class SBJStructureMacroTests: XCTestCase {
    func testStructureMacroIsAvailable() {
        XCTAssertTrue(SBJStructureMacro.self is any Macro.Type)
    }

    func testPropertyInfoMacroIsAvailable() {
        XCTAssertTrue(SBJPropertyInfoMacro.self is any Macro.Type)
    }
}
