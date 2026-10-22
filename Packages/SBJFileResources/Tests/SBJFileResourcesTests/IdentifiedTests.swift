import Foundation
import Testing
@testable import SBJFileResources

@Suite("Identified")
struct IdentifiedTests {
	@Test func identityIsIndependentOfWrappedValue() {
		let id = UUID()
		let first = Identified("one", id: id)
		let second = Identified("two", id: id)
		#expect(first == second)
		#expect(Set([first, second]).count == 1)
	}
}
