import Foundation
import Testing
import SBJDataDefinition
@testable import SBJDocuments
@testable import SBJFoundation
import SBJUIVocabulary

@Suite("Export destination collision handling")
struct ExportDestinationServiceTests {
	@Test("Multi-file export detects every collision before replacing anything")
	func multiFileCollisionIsPromptable() throws {
		let fileManager = FileManager.default
		let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		defer { try? fileManager.removeItem(at: root) }
		let staging = root.appendingPathComponent("staging", isDirectory: true)
		let destination = root.appendingPathComponent("destination", isDirectory: true)
		try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
		try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

		let firstSource = staging.appendingPathComponent("Document.swift")
		let secondSource = staging.appendingPathComponent("portrait.png")
		try Data("new swift".utf8).write(to: firstSource)
		try Data("new portrait".utf8).write(to: secondSource)
		try Data("old swift".utf8).write(to: destination.appendingPathComponent("Document.swift"))
		try Data("old portrait".utf8).write(to: destination.appendingPathComponent("portrait.png"))

		let service = ExportDestinationService(fileManager: fileManager)
		let result = try service.export([firstSource, secondSource], to: destination, replacingExisting: false)
		switch result {
		case .exported:
			Issue.record("Export should require replacement confirmation")
		case .needsReplacement(let collisions):
			#expect(Set(collisions.map(\.name)) == ["Document.swift", "portrait.png"])
		}

		#expect(try Data(contentsOf: destination.appendingPathComponent("Document.swift")) == Data("old swift".utf8))
		#expect(try Data(contentsOf: destination.appendingPathComponent("portrait.png")) == Data("old portrait".utf8))

		_ = try service.export([firstSource, secondSource], to: destination, replacingExisting: true)
		#expect(try Data(contentsOf: destination.appendingPathComponent("Document.swift")) == Data("new swift".utf8))
		#expect(try Data(contentsOf: destination.appendingPathComponent("portrait.png")) == Data("new portrait".utf8))
	}

	@Test("Package export replaces an existing package only after confirmation")
	func packageCollisionIsPromptable() throws {
		let fileManager = FileManager.default
		let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		defer { try? fileManager.removeItem(at: root) }
		let staging = root.appendingPathComponent("staging", isDirectory: true)
		let destination = root.appendingPathComponent("destination", isDirectory: true)
		try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
		try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

		let sourcePackage = staging.appendingPathComponent("Document.example", isDirectory: true)
		let destinationPackage = destination.appendingPathComponent("Document.example", isDirectory: true)
		try fileManager.createDirectory(at: sourcePackage, withIntermediateDirectories: true)
		try fileManager.createDirectory(at: destinationPackage, withIntermediateDirectories: true)
		try Data("new package".utf8).write(to: sourcePackage.appendingPathComponent("document.json"))
		try Data("old package".utf8).write(to: destinationPackage.appendingPathComponent("document.json"))

		let service = ExportDestinationService(fileManager: fileManager)
		let result = try service.export([sourcePackage], to: destination, replacingExisting: false)
		switch result {
		case .exported:
			Issue.record("Package export should require replacement confirmation")
		case .needsReplacement(let collisions):
			#expect(collisions.map(\.name) == ["Document.example"])
		}

		#expect(try Data(contentsOf: destinationPackage.appendingPathComponent("document.json")) == Data("old package".utf8))
		_ = try service.export([sourcePackage], to: destination, replacingExisting: true)
		#expect(try Data(contentsOf: destinationPackage.appendingPathComponent("document.json")) == Data("new package".utf8))
	}
}
