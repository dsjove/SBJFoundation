import Foundation
import SBJLocalization
import SBJStructure

public enum SBJSemanticReadOperation: String, CaseIterable, Sendable {
	/// Exact value at the selected path, including its visible descendants.
	case read
	/// Immediate child addresses and titles, without recursively dumping values.
	case children
	/// Number of items in an array, set, or dictionary (not object properties).
	case count
	/// Declared semantic metadata and current availability at the selected path.
	case describe
}

public enum SBJSemanticReadError: LocalizedError, Equatable, Sendable {
	case graphTooDeep(String)
	case duplicatePath(String)
	case noPaths
	case unknownPath(String)
	case notACollection(String)
	case inconsistentPayload(String)

	public var errorDescription: String? {
		switch self {
		case .graphTooDeep(let path): "The structural graph is recursive or exceeds the supported traversal depth at \(path)."
		case .duplicatePath(let path): "The structural graph has a duplicate access path: \(path)."
		case .noPaths: "Select at least one access path."
		case .unknownPath(let path): "No such access path in this document snapshot: \(path)."
		case .notACollection(let path): "Count is only available for present arrays, sets and dictionaries: \(path)."
		case .inconsistentPayload(let path): "Generated associated-value metadata is inconsistent at \(path)."
		}
	}
}

/// An immutable, Sendable snapshot of the user-facing graph. Native tools can
/// read it concurrently without capturing the model, host, key paths or editor.
/// All collection addresses are local to this snapshot, never deferred edits.
public struct SBJSemanticReadSnapshot: Sendable {
	public struct Entry: Sendable, Equatable {
		public let path: String
		public let title: String
		public let swiftType: String
		public let kind: String
		public let description: String
		public let count: Int?
	}

	private struct Node: Sendable {
		let path: String
		let name: String
		var title: String
		let swiftType: String
		let kind: Kind
		var description: String
		var value: SBJSemanticValue?
		var children: [Node]
		var isRuntimeLabel = false
		var aliases: [String] = []

		enum Kind: String, Sendable {
			case object, array, set, dictionary, entry, associatedEnum, payload, scalar, absent, presentationOnly, unavailable
			var isCollection: Bool { self == .array || self == .set || self == .dictionary }
		}

		var entry: Entry {
			.init(path: path, title: title, swiftType: swiftType, kind: kind.rawValue,
				  description: description, count: kind.isCollection ? children.count : nil)
		}

		var readValue: SBJSemanticValue {
			if let value { return value }
			if kind.isCollection { return .array(children.map(\.readValue)) }
			return .object(Dictionary(uniqueKeysWithValues: children.map { ($0.name, $0.readValue) }))
		}
	}

	public let rootType: String
	public let entries: [Entry]
	private let nodes: [String: Node]
	/// Dynamic labels and membership only. Static declarations are in the type schema.
	public let instanceAccessDescription: String

	public init<Root>(instance: Root) throws {
		let rootType = Swift.type(of: instance as Any)
		self.rootType = String(describing: rootType)
		let root = try Self.build(instance as Any, type: rootType, path: "$", name: "$",
								  title: (rootType as? any SBJNomenclatureProviding.Type)?.nomenclature.nonEmptyTitle ?? String(describing: rootType),
								  description: SBJSemanticDescription.type(rootType), constraints: [], hints: [], depth: 0)
		var nodes: [String: Node] = [:]
		var entries: [Entry] = []
		var manifest: [String] = []
		func collect(_ node: Node) throws {
			guard nodes.updateValue(node, forKey: node.path) == nil else { throw SBJSemanticReadError.duplicatePath(node.path) }
			entries.append(node.entry)
			if node.isRuntimeLabel {
				// Escape line breaks and quotes in runtime labels for the human-readable catalog.
				manifest.append("\(node.path): \(String(reflecting: node.title))")
			}
			if node.kind.isCollection { manifest.append("\(node.path): \(node.kind.rawValue), \(node.children.count) entries") }
			if node.kind == .absent { manifest.append("\(node.path): absent (nil)") }
			if node.kind == .associatedEnum, let tag = node.children.first?.value?.label {
				manifest.append("\(node.path): active case \(String(reflecting: tag))")
			}
			for child in node.children { try collect(child) }
		}
		try collect(root)
		self.entries = entries
		self.nodes = nodes
		self.instanceAccessDescription = manifest.joined(separator: "\n")
	}

	public var paths: [String] { entries.map(\.path) }

	/// Locate visible fields and collection members without sending the complete
	/// access catalog to the model. Prefer exact names and titles, then the
	/// canonical structural text matcher. Return a small set of address choices.
	public func find(_ query: String, limit: Int = 6) -> SBJSemanticValue {
		let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !term.isEmpty, limit > 0 else { return .object(["matches": .array([]), "total": .signed(0)]) }
		func exact(_ text: String) -> Bool {
			text.compare(term, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
		}
		let matches = entries.compactMap { entry -> (Entry, Int)? in
			guard let node = nodes[entry.path] else { return nil }
			if exact(node.name) || exact(entry.title) || exact(entry.path) || node.aliases.contains(where: exact) { return (entry, 0) }
			if sbjPredicated(entry.title, search: term) || sbjPredicated(node.name, search: term) { return (entry, 1) }
			if sbjPredicated(entry.description, search: term) { return (entry, 2) }
			if sbjPredicated(entry.path, search: term) { return (entry, 3) }
			return nil
		}.sorted { lhs, rhs in
			if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
			if lhs.0.path.count != rhs.0.path.count { return lhs.0.path.count < rhs.0.path.count }
			return lhs.0.path < rhs.0.path
		}
		let rows = matches.prefix(limit).map { entry, _ in
			SBJSemanticValue.object(["path": .text(entry.path), "title": .text(entry.title), "kind": .text(entry.kind)])
		}
		return .object(["matches": .array(rows), "total": .signed(Int64(matches.count))])
	}

	/// Addresses must be copied exactly from the schema/catalog. No guessed
	/// aliases, key-path interpretation, file access or executable Swift.
	public func query(_ operation: SBJSemanticReadOperation, paths: [String], childrenOffset: Int = 0,
					  childrenLimit: Int? = nil) throws -> SBJSemanticValue {
		guard !paths.isEmpty else { throw SBJSemanticReadError.noPaths }
		struct Result {
			let path: String
			let title: String
			let swiftType: String
			let kind: String
			let value: SBJSemanticValue?
			let count: Int?
			let children: [Entry]?
			let description: String?
			var totalChildren: Int? = nil
			var nextOffset: Int? = nil
			var content: SBJSemanticValue {
				var fields: [String: SBJSemanticValue] = [
					"path": .text(path), "title": .text(title), "swiftType": .text(swiftType), "kind": .text(kind)
				]
				if let value { fields["value"] = value }
				if let count { fields["count"] = .signed(Int64(count)) }
				if let description { fields["description"] = .text(description) }
				if let totalChildren { fields["totalChildren"] = .signed(Int64(totalChildren)) }
				if let nextOffset { fields["nextOffset"] = .signed(Int64(nextOffset)) }
				if let children {
					fields["children"] = .array(children.map { entry in
						var child: [String: SBJSemanticValue] = ["path": .text(entry.path), "title": .text(entry.title),
							"kind": .text(entry.kind)]
						if let count = entry.count { child["count"] = .signed(Int64(count)) }
						return .object(child)
					})
				}
				return .object(fields)
			}

		}
		var seen = Set<String>()
		let result = try paths.filter { seen.insert($0).inserted }.map { path -> Result in
			guard let node = nodes[path] else { throw SBJSemanticReadError.unknownPath(path) }
			switch operation {
			case .read:
				return .init(path: path, title: node.title, swiftType: node.swiftType, kind: node.kind.rawValue,
							 value: node.readValue, count: node.entry.count, children: nil, description: nil)
			case .children:
				let start = min(max(0, childrenOffset), node.children.count)
				let remaining = node.children.dropFirst(start)
				let page = remaining.prefix(max(1, childrenLimit ?? remaining.count)).map(\.entry)
				let end = start + page.count
				return .init(path: path, title: node.title, swiftType: node.swiftType, kind: node.kind.rawValue,
							 value: nil, count: node.entry.count, children: page, description: nil,
							 totalChildren: node.children.count, nextOffset: end < node.children.count ? end : nil)
			case .count:
				guard let count = node.entry.count else { throw SBJSemanticReadError.notACollection(path) }
				return .init(path: path, title: node.title, swiftType: node.swiftType, kind: node.kind.rawValue,
							 value: nil, count: count, children: nil, description: nil)
			case .describe:
				return .init(path: path, title: node.title, swiftType: node.swiftType, kind: node.kind.rawValue,
							 value: nil, count: node.entry.count, children: nil, description: node.description)
			}
		}
		return .array(result.map(\.content))
	}

	private static func path(_ parent: String, _ component: String) -> String {
		parent + "/" + component.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
	}

	private static func build(_ value: Any, type: Any.Type, path: String, name: String, title: String,
							  description: String, constraints: [SBJPropertyConstraint], hints: [SBJPropertyHint], depth: Int) throws -> Node {
		guard depth < 128 else { throw SBJSemanticReadError.graphTooDeep(path) }
		var type = type
		var value = value
		let declaredType = String(describing: type)
		// Optional wrappers have no address of their own. Nil is a real value,
		// not an empty collection, a zero, or an unavailable field.
		while case .optional(let wrapped)? = SBJStructuralType.container(of: type) {
			guard let container = value as? any SBJStructuralValueContainer,
				  let child = container.sbjStructuralChildren(itemTitleKey: nil, itemIdentifierKey: nil).first else {
				return .init(path: path, name: name, title: title, swiftType: declaredType, kind: .absent,
							 description: description, value: .null, children: [])
			}
			value = child.value
			type = wrapped
		}
		func node(_ kind: Node.Kind, value: SBJSemanticValue? = nil, children: [Node] = []) -> Node {
			.init(path: path, name: name, title: title, swiftType: declaredType, kind: kind,
				  description: description, value: value, children: children)
		}

		if let structured = value as? any SBJStructured {
			return try node(.object, children: objectChildren(structured, parent: path, depth: depth + 1))
		}
		if let container = value as? any SBJStructuralValueContainer,
		   let containerType = SBJStructuralType.container(of: type) {
			let parts = container.sbjStructuralChildren(itemTitleKey: nil, itemIdentifierKey: nil)
			let projection = SBJConstraintProjection(constraints)
			switch containerType {
			case .array(let elementType), .set(let elementType):
				let isSet: Bool
				if case .set = containerType { isSet = true } else { isSet = false }
				let children = try parts.enumerated().map { index, child -> Node in
					var item = try build(child.value, type: elementType, path: Self.path(path, String(index)), name: String(index),
										 title: isSet ? "Member \(index)" : "Item \(index)",
										 description: SBJSemanticDescription.join([SBJSemanticDescription.type(elementType), SBJSemanticDescription.rules(projection.collectionElement.constraints)]),
										 constraints: projection.collectionElement.constraints, hints: [], depth: depth + 1)
					// Use only visible captured fields, not reflected descriptions
					// (which can contain excluded/private state).
					let configured = SBJStructuralCollectionKeys.title(in: hints)
					let preferred = configured.map { [$0] } ?? ["name", "title"]
					let label = preferred.lazy.compactMap { key in item.children.first { $0.name == key }?.value?.label }.first
						?? (elementType == Data.self ? nil : item.value?.label)
					if let label, !label.isEmpty { item.title = label }
					item.isRuntimeLabel = true
					return item
				}
				return node(isSet ? .set : .array, children: children)
			case .dictionary(let keyType, let valueType):
				// The canonical traversal supplies the original typed key, not
				// the display string as a substitute for the key.
				let keyLabels = parts.map { child in
					keyType == Data.self ? nil : child.dictionaryKey.flatMap { SBJSemanticScalarReading.value($0, type: keyType)?.label }
				}
				let labelCounts = Dictionary(keyLabels.compactMap { $0 }.map { ($0, 1) }, uniquingKeysWith: +)
				let children = try parts.enumerated().map { index, child -> Node in
					guard let key = child.dictionaryKey else { throw SBJSemanticReadError.unknownPath("Dictionary key at \(path), entry \(index)") }
					let label = keyLabels[index]
					// Namespace key-based and ordinal fallback components, and
					// use ordinals when distinct typed keys have identical labels.
					let component: String
					if let label, labelCounts[label] == 1 { component = "key:" + label }
					else { component = "entry:\(index)" }
					let entryPath = Self.path(path, component)
					let keyNode = try build(key, type: keyType, path: Self.path(entryPath, "key"), name: "key", title: "Key",
											description: SBJSemanticDescription.join([SBJSemanticDescription.type(keyType), SBJSemanticDescription.rules(projection.dictionaryKey.constraints)]),
											constraints: projection.dictionaryKey.constraints, hints: [], depth: depth + 1)
					let valueNode = try build(child.value, type: valueType, path: Self.path(entryPath, "value"), name: "value", title: "Value",
											  description: SBJSemanticDescription.join([SBJSemanticDescription.type(valueType), SBJSemanticDescription.rules(projection.dictionaryValue.constraints)]),
											  constraints: projection.dictionaryValue.constraints, hints: [], depth: depth + 1)
					return Node(path: entryPath, name: component, title: label ?? "Entry \(index)", swiftType: "Dictionary entry (\(keyType), \(valueType))",
								kind: .entry, description: "Typed key and value; key is not a display label.", value: nil,
								children: [keyNode, valueNode], isRuntimeLabel: true)
				}
				return node(.dictionary, children: children)
			case .optional: break // Already unwrapped above.
			}
		}
		if let associated = value as? any SBJStructuredEnum {
			return try node(.associatedEnum, children: associatedChildren(associated, parent: path, depth: depth + 1))
		}
		if let scalar = SBJSemanticScalarReading.value(value, type: type) { return node(.scalar, value: scalar) }
		if let presentation = value as? any SBJTextPresentable {
			return node(.presentationOnly, value: .object(["presentationOnly": .text(presentation.presentedValue)]))
		}
		return node(.unavailable, value: .object(["unavailable": .text("No semantic read adapter for \(type).")]))
	}

	private static func objectChildren<Root: SBJStructured>(_ root: Root, parent: String, depth: Int) throws -> [Node] {
		try Root.sbjUserFacingProperties.map { property in
			var child = try build(property.value(in: root), type: property.valueType, path: path(parent, property.sourceName),
								  name: property.sourceName, title: property.displayName,
								  description: SBJSemanticDescription.property(property), constraints: property.constraints, hints: property.hints, depth: depth)
			child.aliases = property.info?.aliases ?? []
			return child
		}
	}

	private static func associatedChildren<Root: SBJStructuredEnum>(_ root: Root, parent: String, depth: Int) throws -> [Node] {
		let caseName = root.sbjCaseName
		let info = Root.sbjCaseNomenclature(for: caseName)
		let tag = Node(path: path(parent, "caseName"), name: "caseName", title: "Active case", swiftType: "String", kind: .scalar,
					   description: SBJSemanticDescription.join(["Source-level enum case", SBJSemanticDescription.nomenclature(info)]), value: .text(caseName), children: [])
		guard let active = Root.sbjAssociatedCases.first(where: { $0.matches(root) }) else { return [tag] }
		let parts = root.sbjStructuralAssociatedChildren().dropFirst()
		guard parts.count == active.associatedValues.count,
			  zip(active.associatedValues, parts).allSatisfy({ $0.0.name == $0.1.title }) else {
			throw SBJSemanticReadError.inconsistentPayload(parent)
		}
		guard !parts.isEmpty else { return [tag] }
		let payloadPath = path(parent, "payload")
		let payload = try zip(active.associatedValues, parts).map { property, part in
			try build(part.value, type: property.valueType, path: path(payloadPath, property.name), name: property.name,
					  title: property.name, description: SBJSemanticDescription.type(property.valueType), constraints: [], hints: [], depth: depth + 1)
		}
		return [tag, .init(path: payloadPath, name: "payload", title: info?.nonEmptyTitle ?? caseName,
						   swiftType: "\(Root.self).\(caseName) payload", kind: .payload,
						   description: SBJSemanticDescription.nomenclature(info), value: nil, children: payload)]
	}
}
