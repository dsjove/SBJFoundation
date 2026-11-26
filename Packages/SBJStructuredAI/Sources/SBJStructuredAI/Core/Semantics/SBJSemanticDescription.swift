import Foundation
import SBJLocalization
import SBJStructure

/// The model's declaration-site vocabulary, shared by the type schema and read catalog.
/// No model values are used to construct a static property description.
enum SBJSemanticDescription {
	static func nomenclature(_ info: SBJNomenclature?) -> String {
		guard let info else { return "" }
		return [
			info.nonEmptyTitle.map { "Title: \($0)" },
			info.details,
			info.aliases.isEmpty ? nil : "Aliases: " + info.aliases.joined(separator: ", "),
		].compactMap { $0 }.joined(separator: ". ")
	}

	static func type(_ type: Any.Type) -> String {
		nomenclature((type as? any SBJNomenclatureProviding.Type)?.nomenclature)
	}

	static func rules(_ constraints: [SBJPropertyConstraint], _ hints: [SBJPropertyHint] = []) -> String {
		(constraints.map(\.description) + hints.map(\.description)).joined(separator: "; ")
	}

	static func property<Root>(_ property: SBJPropertyMetadata<Root>, includeDictionaryMemberRules: Bool = true) -> String {
		let constraints = property.constraints.filter { constraint in
			if includeDictionaryMemberRules { return true }
			switch constraint {
			case .dictionaryKeyRule, .dictionaryValueRule: return false
			default: return true
			}
		}
		return join([
			property.info?.nonEmptyTitle == nil ? property.displayName : "",
			"Swift type: \(property.valueType); category: \(property.kind)",
			"\(property.storage == .stored ? "Stored" : "Computed"), \(property.access == .readWrite ? "writable in the application" : "read-only")",
			nomenclature(property.info),
			rules(constraints, property.hints),
		])
	}

	static func enumCases(_ type: any SBJEnumCaseIdentifiable.Type, includeUndocumented: Bool = true) -> String {
		type.sbjCaseNames.compactMap { name -> String? in
			let description = nomenclature(type.sbjCaseNomenclature(for: name))
			guard includeUndocumented || !description.isEmpty else { return nil }
			return join([name, description])
		}.joined(separator: "; ")
	}

	static func join(_ parts: [String]) -> String {
		parts.filter { !$0.isEmpty }.joined(separator: ". ")
	}
}
