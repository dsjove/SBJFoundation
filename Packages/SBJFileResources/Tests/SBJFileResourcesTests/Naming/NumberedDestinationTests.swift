import Foundation
import Testing
@testable import SBJFileResources

struct NumberedDestinationTests {
    @Test func collisionNamesPreserveFileExtensions() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("NumberedDestination-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("Actor.txt")
        #expect(file.uniqueNumberedDestination(in: folder) == file)
        try Data().write(to: file)
        let numbered = file.uniqueNumberedDestination(in: folder)
        #expect(numbered.lastPathComponent == "Actor 1.txt")
        try Data().write(to: numbered)
        #expect(file.uniqueNumberedDestination(in: folder).lastPathComponent == "Actor 2.txt")
    }

    @Test func existingNumberedNamesAdvanceWithoutDoubleNumbering() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("NumberedDestination-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("Clip 7.mov")
        try Data().write(to: file)
        #expect(file.uniqueNumberedDestination(in: folder).lastPathComponent == "Clip 8.mov")
    }
}
