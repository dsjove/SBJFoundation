import Foundation
import Testing
@testable import SBJFileResources

@Suite("Embedded attachment sizing")
struct EmbeddedAttachmentSizeTests {
    @Test func countsDirectoryBytesAndStopsAtLimit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmbeddedSize-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 5).write(to: root.appendingPathComponent("first.bin"))
        let nested = root.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 2, count: 8).write(to: nested.appendingPathComponent("second.bin"))

        #expect(try root.embeddedSize() == 13)
        #expect(try root.embeddedSize(maximumBytes: 10) > 10)
        #expect(try root.appendingPathComponent("first.bin").embeddedSize() == 5)
    }

    @Test func symlinkDoesNotCountExternalBytes() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmbeddedSymlink-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let external = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExternalSize-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: external) }
        try Data(repeating: 3, count: 100).write(to: external)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link"), withDestinationURL: external)
        #expect(try root.embeddedSize() == 0)
    }
}
