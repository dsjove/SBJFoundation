import SBJUIVocabulary
import Foundation
import SBJDataDefinition
import SBJFileResources
import Testing
@testable import SBJFoundation
@testable import SBJDocuments

@Suite("Coordinated file access")
struct FileResourceAccessTests {
	@Test("Security-scoped reads coordinate the supplied URL")
	func securityScopedRead() throws {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let file = directory.appendingPathComponent("value.txt")
		defer { try? FileManager.default.removeItem(at: directory) }
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try Data("value".utf8).write(to: file)

		let value = try CoordinatedFileAccess().readSecurityScoped(at: file) {
			try String(contentsOf: $0, encoding: .utf8)
		}

		#expect(value == "value")
	}
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
