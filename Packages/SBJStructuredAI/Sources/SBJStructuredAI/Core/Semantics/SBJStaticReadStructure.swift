import Foundation
import SBJLocalization
import SBJStructure

/// The model-facing definition is derived solely from declared types. Paths
/// describe declarations, not instance addresses or collection cardinalities.
struct SBJStaticReadStructure: Sendable {
	enum Step: Equatable, Sendable {
		case field(String), member, enumPayload([String], String), memberName
	}

	struct Declaration: Sendable {
		let id: Int
		let title: String
		let path: [Step]
		let type: String
		let description: String
		let info: SBJNomenclature?
		let cases: [String]
		let isCollection: Bool

		var metadata: SBJSemanticValue {
			var fields: [String: SBJSemanticValue] = [
				"id": .signed(Int64(id)), "title": .text(title),
				"type": .text(type), "description": .text(description.isEmpty ? title : description),
				"nomenclature": .object([
					"title": .text(info?.nonEmptyTitle ?? title),
					"summary": info?.summary.map(SBJSemanticValue.text) ?? .null,
					"details": info?.details.map(SBJSemanticValue.text) ?? .null,
					"aliases": .array((info?.aliases ?? []).map(SBJSemanticValue.text))
				])
			]
			if !cases.isEmpty { fields["cases"] = .array(cases.map(SBJSemanticValue.text)) }
			return .object(fields)
		}
	}

	/// All occurrence paths grouped by their shared model-facing declaration ID.
	let declarations: [[Declaration]]
	let compact: String
	let expanded: String

	init(type: Any.Type, traversalOptions: SBJTraversalOptions = .all) throws {
		var builder = Builder(traversalOptions: traversalOptions)
		let info = (type as? any SBJNomenclatureProviding.Type)?.nomenclature
		let root = try builder.node(type: type, title: info?.nonEmptyTitle ?? String(describing: type),
									path: [], info: info, description: SBJSemanticDescription.type(type), ancestors: [])
		if let root {
			let catalog = SBJCompactStructure.catalog(root)
			var groups = Array(repeating: [Declaration](), count: catalog.declarationCount)
			for occurrence in builder.declarations {
				guard let id = catalog.identifiers[occurrence.id] else {
					throw SBJSemanticReadError.inconsistentPayload("Missing declaration \(occurrence.id)")
				}
				groups[id - 1].append(.init(id: id, title: occurrence.title, path: occurrence.path,
					type: occurrence.type, description: occurrence.description, info: occurrence.info,
					cases: occurrence.cases, isCollection: occurrence.isCollection))
			}
			guard groups.allSatisfy({ !$0.isEmpty }) else {
				throw SBJSemanticReadError.inconsistentPayload("Empty shared declaration group")
			}
			declarations = groups
			compact = catalog.compact
			expanded = catalog.expanded
		} else {
			declarations = []
			compact = ""
			expanded = ""
		}
	}

	private struct Builder {
        let traversalOptions: SBJTraversalOptions
		var declarations: [Declaration] = []

		static func names(_ title: String, _ info: SBJNomenclature?) -> String {
			func folded(_ text: String) -> String {
				text.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
			}
			var seen = Set([folded(title)])
			let aliases = (info?.aliases ?? []).filter { !$0.isEmpty && seen.insert(folded($0)).inserted }
			return ([title] + aliases).map(SBJCompactStructure.name).joined(separator: ",")
		}

		mutating func node(type declared: Any.Type, title: String, path: [Step], info supplied: SBJNomenclature?,
						   description: String, ancestors: Set<ObjectIdentifier>,
						   constraints: [SBJPropertyConstraint] = [], collectionMember: Bool = false, omitDeclaration: Bool = false, hints: [SBJPropertyHint] = [], configuredMemberName: Bool = false) throws -> SBJCompactStructure.Node? {
			var type = declared
			var optional = false
			while case .optional(let wrapped)? = SBJStructuralType.container(of: type) {
				optional = true
				type = wrapped
			}
			let info = supplied ?? (type as? any SBJNomenclatureProviding.Type)?.nomenclature
			let identity = ObjectIdentifier(type)
			guard !ancestors.contains(identity), ancestors.count < 128 else {
				throw SBJSemanticReadError.graphTooDeep(title)
			}
			var next = ancestors
			next.insert(identity)
			let container = SBJStructuralType.container(of: type)
			let marker: String
			switch container {
			case .array?: marker = "|"
			case .set?: marker = "*"
			case .dictionary?: marker = ":"
			default: marker = !SBJStructuralType.isAtomic(type) && (type is any SBJStructured.Type || type is any SBJStructuredEnum.Type) ? "+" : "-"
			}
			let enumeration = type as? any SBJEnumCaseIdentifiable.Type
			let id = omitDeclaration ? 0 : declarations.count + 1
			if !omitDeclaration { declarations.append(.init(id: id, title: title, path: path, type: String(describing: declared),
									  description: description, info: info, cases: enumeration?.sbjCaseNames ?? [],
									  isCollection: container != nil || optional)) }
			let projection = SBJConstraintProjection(constraints)
			var children: [SBJCompactStructure.Node] = []
			switch container {
			case .array(let element)?, .set(let element)?:
				let nested = SBJStructuralType.container(of: element) != nil
				if let child = try node(type: element, title: "Element", path: path + [.member], info: nil,
										description: SBJSemanticDescription.join([SBJSemanticDescription.type(element), SBJSemanticDescription.rules(projection.collectionElement.constraints)]),
										ancestors: next, constraints: projection.collectionElement.constraints, collectionMember: true, omitDeclaration: !nested, configuredMemberName: SBJStructuralCollectionKeys.title(in: hints) != nil) {
					// Collection element shape is implicit; nested collections retain a node.
					children = nested ? [child] : child.children
				}
			case .dictionary(let key, let value)?:
				let entryPath = path + [.member]
				let keyNode = try node(type: key, title: "Key", path: entryPath + [.field("key")], info: nil,
									   description: SBJSemanticDescription.join([SBJSemanticDescription.type(key), SBJSemanticDescription.rules(projection.dictionaryKey.constraints)]), ancestors: next, constraints: projection.dictionaryKey.constraints)
				let valueNode = try node(type: value, title: "Value", path: entryPath + [.field("value")], info: nil,
										 description: SBJSemanticDescription.join([SBJSemanticDescription.type(value), SBJSemanticDescription.rules(projection.dictionaryValue.constraints)]), ancestors: next, constraints: projection.dictionaryValue.constraints, collectionMember: true, configuredMemberName: SBJStructuralCollectionKeys.title(in: hints) != nil)
				children = [keyNode, valueNode].compactMap { $0 }
			default:
				if SBJStructuralType.isAtomic(type) {
					break
				} else if let associated = type as? any SBJStructuredEnum.Type {
					children = try enumChildren(associated, path: path, ancestors: next)
				} else if let structure = type as? any SBJStructured.Type {
					children = try properties(structure, path: path, ancestors: next)
				}
			}
			if collectionMember, configuredMemberName, marker == "+", !SBJCollectionItemIdentification.hasDeclaredName(type) {
				let nameID = declarations.count + 1
				declarations.append(.init(id: nameID, title: "name", path: path + [.memberName], type: "String?", description: SBJAIInstructions.memberNameDescription, info: nil, cases: [], isCollection: false))
				children.append(.init(identifier: nameID, label: "?-name"))
			}
			// Empty structures are omitted, but optional presence and collection
			// counts remain addressable even when their element type is opaque.
			if marker == "+", children.isEmpty, !optional, enumeration == nil {
				if !omitDeclaration { declarations.removeLast() }
				return nil
			}
			// Only compound business structures can participate in consolidation.
			// A collection of compound values uses its element definition, not
			// the identity of the collection wrapper. Leaves are never candidates.
			let templateType: Any.Type?
			switch container {
			case .array(let element)?, .set(let element)?: templateType = element
			case nil: templateType = type
			default: templateType = nil
			}
			let compound = templateType.flatMap { candidate -> Any.Type? in
				guard !SBJStructuralType.isAtomic(candidate), candidate is any SBJStructured.Type || candidate is any SBJStructuredEnum.Type else { return nil }
				return candidate
			}
			return .init(identifier: id, label: (optional ? "?" : "") + marker + Self.names(title, info), children: children,
						 structuralType: compound.map { ObjectIdentifier($0) })
		}

		mutating func properties<Root: SBJStructured>(_ type: Root.Type, path: [Step], ancestors: Set<ObjectIdentifier>) throws -> [SBJCompactStructure.Node] {
			var result: [SBJCompactStructure.Node] = []
			for declaration in SBJStructuralTraversal.definition(of: type, options: traversalOptions) {
				let property = declaration.metadata
				if let child = try node(type: declaration.valueType, title: declaration.displayName,
										path: path + [.field(declaration.sourceName)], info: declaration.info,
										description: SBJSemanticDescription.property(property), ancestors: ancestors,
										constraints: declaration.constraints, hints: property.hints) { result.append(child) }
			}
			return result
		}

		private struct PayloadKey: Hashable {
			let name: String
			let type: ObjectIdentifier
		}

		mutating func enumChildren<Root: SBJStructuredEnum>(_ type: Root.Type, path: [Step], ancestors: Set<ObjectIdentifier>) throws -> [SBJCompactStructure.Node] {
			// Merge same-named, same-typed payloads. Case membership is retained
			// in the read path; a declaration never selects an inactive payload.
			var groups: [(name: String, type: Any.Type, cases: [String])] = []
			var indices: [PayloadKey: Int] = [:]
			for name in type.sbjCaseNames {
				for value in type.sbjAssociatedCases.first(where: { $0.sourceName == name })?.associatedValues ?? [] {
					let key = PayloadKey(name: value.name, type: ObjectIdentifier(value.valueType))
					if let index = indices[key] {
						groups[index].cases.append(name)
					} else {
						indices[key] = groups.count
						groups.append((value.name, value.valueType, [name]))
					}
				}
			}
			var result: [SBJCompactStructure.Node] = []
			for group in groups {
				let ambiguous = groups.filter { $0.name == group.name }.count > 1
				let title = ambiguous ? group.name + " " + group.cases.joined(separator: "/") : group.name
				if let child = try node(type: group.type, title: title,
										path: path + [.enumPayload(group.cases, group.name)], info: nil,
										description: SBJSemanticDescription.join([SBJSemanticDescription.type(group.type), SBJAIInstructions.casesDescription(group.cases)]),
										ancestors: ancestors) { result.append(child) }
			}
			return result
		}
	}
}
