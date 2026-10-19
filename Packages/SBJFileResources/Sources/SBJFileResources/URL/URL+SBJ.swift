import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#elseif os(watchOS)
import WatchKit
#endif

public extension String {
    /// Parses a URL after trimming surrounding whitespace and newlines.
    ///
    /// This helper intentionally applies no business-rule policy. Relative URLs and
    /// unusual schemes remain representable; `@SBJURL` constraints are evaluated
    /// only by explicit invariant validation.
    var sbjURL: URL? {
        URL(string: trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public enum URLAttachmentError: LocalizedError {
	case unsupportedItem
	case tooLarge(Int64)

	public var errorDescription: String? {
		switch self {
		case .unsupportedItem:
			"Only files and file packages can be attached."
		case .tooLarge(let maximumBytes):
			"The attachment is too large. Attachments are limited to \(ByteCountFormatter.string(fromByteCount: maximumBytes, countStyle: .file))."
		}
	}
}

public extension URL {
	/// Returns the number of regular-file bytes that would be embedded from this URL.
	///
	/// Regular files report their file size. Directories and packages are walked
	/// recursively. Symbolic links are not followed, which both avoids loops and
	/// keeps the result tied to bytes actually rooted in the selected item.
	/// When `maximumBytes` is supplied, traversal stops as soon as the running
	/// total exceeds that value.
	func embeddedSize(maximumBytes: Int64? = nil) throws -> Int64 {
		let values = try resourceValues(forKeys: [
			.isRegularFileKey,
			.isDirectoryKey,
			.isSymbolicLinkKey,
			.fileSizeKey
		])

		if values.isSymbolicLink == true { return 0 }
		if values.isRegularFile == true { return Int64(values.fileSize ?? 0) }
		guard values.isDirectory == true else { return 0 }

		let keys: Set<URLResourceKey> = [
			.isRegularFileKey,
			.isDirectoryKey,
			.isSymbolicLinkKey,
			.fileSizeKey
		]
		guard let enumerator = FileManager.default.enumerator(
			at: self,
			includingPropertiesForKeys: Array(keys),
			options: []
		) else { return 0 }

		var total: Int64 = 0
		for case let child as URL in enumerator {
			let childValues = try child.resourceValues(forKeys: keys)
			if childValues.isSymbolicLink == true {
				if childValues.isDirectory == true { enumerator.skipDescendants() }
				continue
			}
			guard childValues.isRegularFile == true else { continue }
			total += Int64(childValues.fileSize ?? 0)
			if let maximumBytes, total > maximumBytes { return total }
		}
		return total
	}

	/// Validates the common embedded-attachment policy: a regular file or file
	/// package, optionally no larger than `maximumAttachmentBytes`. Consumers with
	/// different attachment policies can supply their own validator instead.
	func validateAttachmentURL(maximumAttachmentBytes: Int64? = nil) throws {
		let values = try resourceValues(forKeys: [.isRegularFileKey, .isPackageKey])
		guard values.isRegularFile == true || values.isPackage == true else {
			throw URLAttachmentError.unsupportedItem
		}

		guard let maximumAttachmentBytes else { return }
		let size = try embeddedSize(maximumBytes: maximumAttachmentBytes)
		guard size <= maximumAttachmentBytes else {
			throw URLAttachmentError.tooLarge(maximumAttachmentBytes)
		}
	}
}
