import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#elseif os(watchOS)
import WatchKit
#endif

public typealias IdentifiedURL = Identified<URL>
public typealias IdentifiedURLs = Identified<[URL]>

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

/// Platform URL behavior shared by SBJStructure's editor and client UI.
///
/// This deliberately does not use SwiftUI's `openURL` environment. Keeping the
/// behavior on `URL` makes it available to non-SwiftUI callers and preserves the
/// platform-opening path used by existing applications.
@MainActor
public extension URL {
    var isValidURL: Bool {
        guard !absoluteString.isEmpty, scheme != nil else { return false }

#if canImport(UIKit)
#if WIDGET_TARGET
        return true
#else
        return UIApplication.shared.canOpenURL(self)
#endif
#elseif canImport(AppKit)
        return true
#elseif os(watchOS)
        return true
#else
        return true
#endif
    }

    @discardableResult
    static func open(_ urlString: String) -> URL? {
        let url = URL(string: urlString)
        open(url)
        return url
    }

    static func open(_ url: URL?) {
        url?.open()
    }

    func open() {
#if canImport(UIKit)
#if !WIDGET_TARGET
        UIApplication.shared.open(self, options: [:], completionHandler: nil)
#endif
#elseif canImport(AppKit)
        NSWorkspace.shared.open(self)
#elseif os(watchOS)
		WKApplication.shared().openSystemURL(self)
#endif
    }
}

public extension URL {
	/// Performs a synchronous operation while this URL's security-scoped access is active.
	///
	/// URLs that do not require a security scope remain usable; `stopAccessing...` is
	/// balanced only when `startAccessing...` actually started access.
	func withSecurityScopedAccess<T>(_ operation: (URL) throws -> T) rethrows -> T {
#if canImport(Darwin)
		let isAccessing = startAccessingSecurityScopedResource()
		defer {
			if isAccessing {
				stopAccessingSecurityScopedResource()
			}
		}
#endif
		return try operation(self)
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
