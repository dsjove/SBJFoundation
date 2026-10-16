import Foundation

/// Creates export artifacts in an app-owned staging directory.
///
/// This type owns only generic filesystem mechanics: creating staging paths,
/// replacing staged directories, and atomically writing data or text. Domain
/// code remains responsible for choosing user-facing names and serializing its
/// own content.
public struct ExportArtifactWriter: @unchecked Sendable {
	let directoryName: String
	let fileManager: FileManager

	public init(directoryName: String, fileManager: FileManager = .default) {
		self.directoryName = directoryName
		self.fileManager = fileManager
	}

	var stagingDirectory: URL {
		fileManager.temporaryDirectory.appendingPathComponent(directoryName, isDirectory: true)
	}

	public func artifactURL(named name: String, extension ext: String, directory: URL? = nil) throws -> URL {
		let directory = directory ?? stagingDirectory
		try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		return directory.appendingPathComponent(name).appendingPathExtension(ext)
	}

	@discardableResult
	func prepareDirectory(named name: String, extension ext: String, directory: URL? = nil) throws -> URL {
		let url = try artifactURL(named: name, extension: ext, directory: directory)
		try prepareDirectory(at: url)
		return url
	}

	public func prepareDirectory(at url: URL) throws {
		try removeIfExists(at: url)
		try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
	}

	public func removeIfExists(at url: URL) throws {
		if fileManager.fileExists(atPath: url.path) {
			try fileManager.removeItem(at: url)
		}
	}

	@discardableResult
	public func write(_ data: Data, named name: String, extension ext: String, directory: URL? = nil) throws -> URL {
		let url = try artifactURL(named: name, extension: ext, directory: directory)
		try write(data, to: url)
		return url
	}

	@discardableResult
	func write(
		_ string: String,
		named name: String,
		extension ext: String,
		directory: URL? = nil,
		encoding: String.Encoding = .utf8
	) throws -> URL {
		let url = try artifactURL(named: name, extension: ext, directory: directory)
		try write(string, to: url, encoding: encoding)
		return url
	}

	@discardableResult
	func write(_ wrapper: FileWrapper, named name: String, extension ext: String, directory: URL? = nil) throws -> URL {
		let url = try artifactURL(named: name, extension: ext, directory: directory)
		try removeIfExists(at: url)
		try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
		return url
	}

	public func write(_ data: Data, to url: URL) throws {
		try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try data.write(to: url, options: .atomic)
	}

	public func write(_ string: String, to url: URL, encoding: String.Encoding = .utf8) throws {
		try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
		try string.write(to: url, atomically: true, encoding: encoding)
	}
}
