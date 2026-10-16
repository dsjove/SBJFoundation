import Foundation
import SBJDocuments
import Testing
@testable import SBJFoundation

@Suite("Export artifact writer")
struct ExportArtifactWriterTests {
	@Test("Stages atomic data and text artifacts under the configured directory")
	func writesArtifacts() throws {
		let fileManager = FileManager.default
		let directoryName = "SBJFoundationTests-\(UUID().uuidString)"
		let writer = ExportArtifactWriter(directoryName: directoryName, fileManager: fileManager)
		defer { try? fileManager.removeItem(at: writer.stagingDirectory) }

		let dataURL = try writer.write(Data("payload".utf8), named: "Document", extension: "bin")
		let textURL = try writer.write("source", named: "Document", extension: "swift")

		#expect(dataURL.deletingLastPathComponent() == writer.stagingDirectory)
		#expect(try Data(contentsOf: dataURL) == Data("payload".utf8))
		#expect(try String(contentsOf: textURL, encoding: .utf8) == "source")
	}

	@Test("Preparing a staged directory replaces an existing artifact")
	func replacesDirectory() throws {
		let fileManager = FileManager.default
		let directoryName = "SBJFoundationTests-\(UUID().uuidString)"
		let writer = ExportArtifactWriter(directoryName: directoryName, fileManager: fileManager)
		defer { try? fileManager.removeItem(at: writer.stagingDirectory) }

		let directory = try writer.prepareDirectory(named: "Document", extension: "package")
		try Data("old".utf8).write(to: directory.appendingPathComponent("old.dat"))
		let replaced = try writer.prepareDirectory(named: "Document", extension: "package")

		#expect(replaced == directory)
		#expect(!fileManager.fileExists(atPath: replaced.appendingPathComponent("old.dat").path))
	}
}
