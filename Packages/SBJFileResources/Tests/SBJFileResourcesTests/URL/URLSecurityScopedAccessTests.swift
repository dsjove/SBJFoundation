import Foundation
import Testing
@testable import SBJFileResources

@Suite("URL security-scoped access")
struct URLSecurityScopedAccessTests {
	@Test("URL security-scoped helper returns the operation result")
	func urlSecurityScopedAccess() throws {
		let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: file) }
		try Data("scoped".utf8).write(to: file)

		let value = try file.withSecurityScopedAccess { scopedURL in
			try String(contentsOf: scopedURL, encoding: .utf8)
		}

		#expect(value == "scoped")
	}
}
