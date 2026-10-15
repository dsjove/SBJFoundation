import Foundation
import UniformTypeIdentifiers

public extension String {
	func sanitizedFilename(
		removeSpaces: Bool = false,
		replacement: String = "-"
	) -> String {
		let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return "" }

		let originalName = trimmed // we assume no path
		guard !originalName.isEmpty else { return "" }

		let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
			.union(.newlines)
			.union(.illegalCharacters)
			.union(.controlCharacters)

		var result = ""
		var lastWasReplacement = false

		for scalar in originalName.unicodeScalars {
			if invalid.contains(scalar) {
				if !replacement.isEmpty && !lastWasReplacement {
					result += replacement
					lastWasReplacement = true
				}
			} else {
				result.unicodeScalars.append(scalar)
				lastWasReplacement = false
			}
		}

		while result.hasPrefix(replacement), !replacement.isEmpty {
			result.removeFirst(replacement.count)
		}

		while result.hasSuffix(replacement), !replacement.isEmpty {
			result.removeLast(replacement.count)
		}

		if removeSpaces {
			result = result.replacingOccurrences(of: " ", with: "")
		}

		result = result.trimmingCharacters(in: .whitespacesAndNewlines)

		let reservedWindowsNames: Set<String> = [
			"CON", "PRN", "AUX", "NUL",
			"COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
			"LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
		]

		let baseName = URL(fileURLWithPath: result).deletingPathExtension().lastPathComponent
		if reservedWindowsNames.contains(baseName.uppercased()) {
			result = "_" + result
		}

		return result
	}
	/// Returns a sanitized filename, adding the content type's preferred extension
	/// when the supplied name does not already contain one.
	func sanitizedFilename(contentType: UTType) -> String {
		let filename = sanitizedFilename()
		guard !filename.isEmpty else { return filename }
		guard URL(fileURLWithPath: filename).pathExtension.isEmpty,
			  let ext = contentType.preferredFilenameExtension,
			  !ext.isEmpty
		else { return filename }
		return filename + "." + ext
	}

}

public extension String {
    /// Returns a non-colliding filename while preserving the original extension.
    /// Comparison is case-insensitive to match normal user-visible file naming.
    func uniqueFilename<S: Sequence>(existingNames: S) -> String where S.Element == String {
        let existing = existingNames.map { $0.lowercased() }
        guard existing.contains(lowercased()) else { return self }

        let url = URL(fileURLWithPath: self)
        let ext = url.pathExtension
        let stem = url.deletingPathExtension().lastPathComponent

        var index = 2
        while true {
            let candidateStem = "\(stem) \(index)"
            let candidate = ext.isEmpty ? candidateStem : "\(candidateStem).\(ext)"
            if !existing.contains(candidate.lowercased()) {
                return candidate
            }
            index += 1
        }
    }
}
