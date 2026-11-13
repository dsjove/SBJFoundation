import Foundation

public extension Error {
	func printAsNSError() {
		let nsError = self as NSError
		print("• error: \(self)")
		print("• code: \(nsError.code)")
		print("• domain: \(nsError.domain)")
		print("• userInfo: \(nsError.userInfo)")
		print("• description: \(nsError.localizedDescription)")
		print("• reason: \(nsError.localizedFailureReason ?? "")")
		print("• options: \(nsError.localizedRecoveryOptions ?? [])")
		print("• suggestion: \(nsError.localizedRecoverySuggestion ?? "")")
	}

	var detailedDescription: String {
		if let error = self as? DecodingError {
			return error.fullDescription
		}
		return localizedDescription
	}
}

public extension DecodingError {
	var fullDescription: String {
		let context: Context
		let reason: String

		switch self {
		case .keyNotFound(let key, let ctx):
			context = ctx
			reason = "Missing key '\(key.stringValue)'"

		case .typeMismatch(let type, let ctx):
			context = ctx
			reason = "Type mismatch for \(type)"

		case .valueNotFound(let type, let ctx):
			context = ctx
			reason = "Missing value for \(type)"

		case .dataCorrupted(let ctx):
			context = ctx
			reason = "Data corrupted"

		@unknown default:
			return localizedDescription
		}

		let path = context.codingPath
			.map { key in
				if let index = key.intValue {
					return "[\(index)]"
				}
				return key.stringValue
			}
			.joined(separator: ".")

		return """
			\(reason)
			Path: \(path.isEmpty ? "<root>" : path)
			Reason: \(context.debugDescription)
			Underlying: \(context.underlyingError?.localizedDescription ?? "None")
			"""
	}
}
