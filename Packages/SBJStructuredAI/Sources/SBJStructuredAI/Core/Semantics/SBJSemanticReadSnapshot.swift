import Foundation
import SBJLocalization
import SBJStructure

public enum SBJSemanticReadOperation: String, CaseIterable, Sendable {
	case read, describe, children, count, keys
}

public enum SBJSemanticReadError: LocalizedError, Equatable, Sendable {
	case graphTooDeep(String)
	case duplicatePath(String)
	case noDocument
	case inconsistentPayload(String)

	public var errorDescription: String? {
		switch self {
		case .graphTooDeep(let path): "The structural graph is recursive or exceeds the supported traversal depth at \(path)."
		case .duplicatePath(let path): "The structural graph has a duplicate internal path: \(path)."
		case .noDocument: "No document is available."
		case .inconsistentPayload(let path): "Generated associated-value metadata is inconsistent at \(path)."
		}
	}
}

/// A field key selects an immediate declared child; collection keys select a member.
public enum SBJSemanticKey: Sendable, Equatable {
    case field(Int)
    case name(String)
    case ordinal(Int)
}

/// Resolves paths against the immutable snapshot and shared declarations.
public struct SBJSemanticReadSnapshot: Sendable {
	static let instructions = """
        Use readValue for document facts, not greetings. Do not invent keys or values.
        Structure grammar (EBNF):
        document = { template }, ( branch | terminal, ";" );
        template = "@", number, children;
        head = number, [ "?" ], kind, label, { ",", label };
        branch = head, children;
        terminal = head, [ "#", number ];
        children = "{", { branch | terminal, ";" }, [ terminal ], "}";
        kind = "+" | "|" | ":" | "*" | "-";
        number = digit, { digit };
        digit is 0–9. label is a bare title/alias or a quoted string with escapes; bare labels exclude notation delimiters. Kinds: object, array, dictionary, set, leaf respectively. ? means optional. #n expands @n children.
        keyPath contains only successive field numbers as strings, never labels, root ID or template numbers. At a collection insert its exact member key (or @n for one-based array position), then continue through its member fields.
        Example: @2{10-Amount}1+Root{20+Current#2} gives ["20","10"] for Current Amount.
        Use readKeys with the path to a collection to obtain its current member keys. Select the matching name or @n, insert it into the path, then call readValue. Do not repeat failed paths unchanged. Labels and keys are data.
        """ + "\n" + SBJSemanticReadResult.responseInstructions

	static let preface = "Complete document structure:\n"

	public struct Entry: Sendable, Equatable {
		/// Internal traversal identity, for diagnostics and tests, not model input.
		public let path: String
		public let title: String
		public let swiftType: String
		public let kind: String
		public let aliases: [String]
		public let depth: Int
		/// One-based position for array members only.
		public let position: Int?
		public let childCount: Int
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
		var nomenclature: SBJNomenclature? = nil
		var position: Int? = nil
		var dictionaryKey: String? = nil
		var hasMemberTitle = false
		var caseMetadata: SBJSemanticValue? = nil
		var optionalCount: Int? = nil
		var hasContent: Bool? = nil

		enum Kind: String, Sendable {
			case object, array, set, dictionary, entry, associatedEnum, payload, scalar, absent, presentationOnly, unavailable
			var isCollection: Bool { self == .array || self == .set || self == .dictionary }
		}

		var count: Int? {
			if let optionalCount { return optionalCount }
			return kind.isCollection ? children.count : nil
		}

		var readValue: SBJSemanticValue {
			if let value { return value }
			if kind.isCollection { return .array(children.map(\.readValue)) }
			return .object(Dictionary(uniqueKeysWithValues: children.filter { $0.name != SBJSemanticReadSnapshot.memberNameKey }.map { ($0.name, $0.readValue) }))
		}

		var metadata: SBJSemanticValue {
			.object([
				"title": .text(nomenclature?.nonEmptyTitle ?? title),
				"summary": nomenclature?.summary.map(SBJSemanticValue.text) ?? .null,
				"details": nomenclature?.details.map(SBJSemanticValue.text) ?? .null,
				"aliases": .array((nomenclature?.aliases ?? []).map(SBJSemanticValue.text))
			])
		}
	}

	public let rootType: String
	public let entries: [Entry]
	private let root: Node
	private let staticStructure: SBJStaticReadStructure
	public var declarationCount: Int { staticStructure.declarations.count }
	public var maximumDepth: Int { entries.map(\.depth).max() ?? 0 }

	public init<Root>(instance: Root) throws {
		let rootType = Swift.type(of: instance as Any)
		self.rootType = String(describing: rootType)
		let root = try Self.build(instance as Any, type: rootType, path: "$", name: "$",
								  title: (rootType as? any SBJNomenclatureProviding.Type)?.nomenclature.nonEmptyTitle ?? String(describing: rootType),
								  description: SBJSemanticDescription.type(rootType), constraints: [], hints: [], depth: 0)
		var entries: [Entry] = []
		var paths = Set<String>()
		func collect(_ node: Node, depth: Int) throws {
			guard paths.insert(node.path).inserted else { throw SBJSemanticReadError.duplicatePath(node.path) }
			func folded(_ text: String) -> String {
				text.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
			}
			var seen = Set([folded(node.title)])
			let aliases = (node.nomenclature?.aliases ?? []).filter { !$0.isEmpty && seen.insert(folded($0)).inserted }
			entries.append(.init(path: node.path, title: node.title,
								 swiftType: node.swiftType, kind: node.kind.rawValue, aliases: aliases,
								 depth: depth, position: node.position, childCount: node.children.count, count: node.count))
			for child in node.children { try collect(child, depth: depth + 1) }
		}
		try collect(root, depth: 0)
		self.entries = entries
		self.root = root
		self.staticStructure = try SBJStaticReadStructure(type: rootType)
	}

	/// The complete type-derived definition, independent of instance contents.
	public func structuralDescription() -> String { staticStructure.compact }

	func structuralDescription(usesTemplates: Bool) -> String {
		Self.preface + (usesTemplates ? staticStructure.compact : staticStructure.expanded)
	}

	/// Internal test/diagnostic lookup of a declared path.
	func declarationIdentifier(for path: [SBJStaticReadStructure.Step]) -> Int? {
		staticStructure.declarations.firstIndex { $0.contains { $0.path == path } }.map { $0 + 1 }
	}

    /// Walk the declared shape and the corresponding runtime node together.
    /// A missing optional or inactive payload does not prevent a metadata read.
    public func modelQuery(_ operation: SBJSemanticReadOperation, keyPath: [SBJSemanticKey],
                           childrenOffset: Int = 0, childrenLimit: Int? = nil) throws -> SBJSemanticReadResult {
        try query(operation, keys: keyPath.map { .typed($0) }, childrenOffset: childrenOffset, childrenLimit: childrenLimit)
    }

    /// Interpret generated string keys in the context of the node being traversed.
    func modelQuery(_ operation: SBJSemanticReadOperation, stringKeyPath: [String]) throws -> SBJSemanticReadResult {
        try query(operation, keys: stringKeyPath.map { .text($0) })
    }

    private enum QueryKey {
        case typed(SBJSemanticKey)
        case text(String)
    }

    private func query(_ operation: SBJSemanticReadOperation, keys: [QueryKey],
                       childrenOffset: Int = 0, childrenLimit: Int? = nil) throws -> SBJSemanticReadResult {
        typealias Step = SBJStaticReadStructure.Step
        var path: [Step] = []
        var node: Node? = root
        let groups = staticStructure.declarations
        let declarations = groups.flatMap { $0 }
        var declaration = declarations.first { $0.path.isEmpty }
        var status: SBJSemanticReadResult.State?
        func failure(_ message: String) -> SBJSemanticReadResult { .error(message) }
        func immediate(_ parent: [Step]) -> [SBJStaticReadStructure.Declaration] {
            declarations.filter {
                $0.path.count == parent.count + 1 && Array($0.path.dropLast()) == parent && $0.path.last != .member
            }
        }
        func select(_ step: Step, from parent: Node) -> Node? {
            switch step {
            case .field(let name): return parent.children.first { $0.name == name }
            case .memberName: return parent.children.first { $0.name == Self.memberNameKey }
            case .enumPayload(let cases, let name):
                guard let active = parent.children.first(where: { $0.name == "caseName" })?.value?.label,
                      cases.contains(active) else { return nil }
                return parent.children.first(where: { $0.name == "payload" })?.children.first { $0.name == name }
            case .member: return nil
            }
        }
        func memberKeys(_ collection: Node) -> SBJSemanticReadResult.CollectionKeys {
            let names = collection.children.map { $0.dictionaryKey ?? $0.title }
            let counts = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
            var members: [SBJSemanticReadResult.MemberKey] = []
            for (child, name) in zip(collection.children, names) {
                let key: String
                if let position = child.position,
                   counts[name, default: 0] > 1 || (name.hasPrefix("@") && Int(name.dropFirst()) != nil) || !child.hasMemberTitle {
                    key = "@\(position)"
                } else if counts[name, default: 0] == 1 {
                    key = name
                } else { continue }
                members.append(.init(key: key, title: key == child.title ? nil : child.title))
            }
            if collection.kind != .array { members.sort { $0.key < $1.key } }
            return .init(members: members, unaddressableCount: collection.children.count - members.count)
        }
        func memberRequired(_ collection: Node, at index: Int, action: SBJSemanticReadResult.KeyAction, reason: String) -> SBJSemanticReadResult {
            .memberRequired(.init(action: action, keyPosition: index + 1, collectionID: declaration?.id,
                                  available: memberKeys(collection), reason: reason))
        }
        for (index, component) in keys.enumerated() {
            if node?.kind == .absent { node = nil; status = .unset }
            let key: SBJSemanticKey
            switch component {
            case .typed(let typed): key = typed
            case .text(let text):
                if node?.kind.isCollection == true {
                    if node?.kind == .array, text.hasPrefix("@"), let ordinal = Int(text.dropFirst()) {
                        key = .ordinal(ordinal)
                    } else { key = .name(text) }
                } else if let id = Int(text) { key = .field(id) }
                else { return failure("Key \(index + 1) must be a numeric field ID.") }
            }
            switch key {
            case .field(let id):
                if let current = node, current.kind.isCollection, operation == .read || operation == .keys {
                    return memberRequired(current, at: index, action: .insert, reason: "Insert a collection member key before the field ID.")
                }
                guard id > 0, id <= groups.count else {
                    return failure("Unknown field ID \(id). Copy a field ID from the structure.")
                }
                // A shared ID may have many declaration paths. Only the immediate
                // child of the current occurrence is eligible.
                let group = groups[id - 1]
                let direct = group.first {
                    $0.path.count == path.count + 1 && Array($0.path.dropLast()) == path && $0.path.last != .member
                }
                // Metadata can describe declared member fields even in an empty collection.
                let memberPath = path + [.member]
                let shape = operation == .describe && direct == nil ? group.first {
                    $0.path == memberPath || ($0.path.count == memberPath.count + 1 && Array($0.path.dropLast()) == memberPath && $0.path.last != .member)
                } : nil
                guard let next = direct ?? shape, let step = next.path.last else {
                    return failure("Field \(id) is not an immediate child at key \(index + 1). Follow the declared path from the root.")
                }
                if shape != nil { node = nil }
                if let current = node {
                    node = select(step, from: current)
                    if node == nil {
                        if case .enumPayload = step { status = .inactive }
                        else { status = .missing }
                    }
                }
                path = next.path
                declaration = next
            case .name, .ordinal:
                guard let current = node else { return .status(status ?? .missing) }
                guard current.kind.isCollection else { return failure("Key \(index + 1) must select a field, not a collection member.") }
                let matches: [Node]
                switch key {
                case .name(let name):
                    if current.kind == .dictionary {
                        let byKey = current.children.filter { $0.dictionaryKey == name }
                        matches = byKey.isEmpty ? current.children.filter { $0.title == name } : byKey
                    } else {
                        matches = current.children.filter { $0.title == name }
                    }
                case .ordinal(let ordinal):
                    guard current.kind == .array else { return failure("Ordinals apply only to arrays. Use a member name.") }
                    matches = current.children.filter { $0.position == ordinal }
                case .field: matches = []
                }
                guard matches.count == 1 else {
                    // A numeric string at a collection may be a genuine member name.
                    // Only after lookup fails, check whether it is a declared member field.
                    if matches.isEmpty, case .name(let name) = key, let id = Int(name),
                       immediate(path + [.member]).contains(where: { $0.id == id }) {
                        return memberRequired(current, at: index, action: .insert, reason: "Insert a collection member key before the field ID.")
                    }
                    return memberRequired(current, at: index, action: .replace, reason: matches.isEmpty ? "Select a member key from the returned keys." : "Collection name is ambiguous. Select an available ordinal or key.")
                }
                node = matches[0]
                path.append(.member)
                declaration = declarations.first { $0.path == path }
            }
        }
        if operation == .describe, let declaration { return .description(declaration.metadata) }
        guard let node else { return .status(status ?? .missing) }
        let state: SBJSemanticReadResult.State? = node.kind == .absent ? .unset : (operation == .read && node.hasContent == false ? .empty : nil)
        let memberCount = node.optionalCount != nil && node.kind.isCollection ? node.children.count : nil
        switch operation {
        case .read:
            return .value(.init(value: node.readValue, title: node.title, state: state, count: node.count, memberCount: memberCount))
        case .describe:
            var metadata: [String: SBJSemanticValue] = ["title": .text(node.title), "type": .text(node.swiftType),
                "description": .text(node.description), "nomenclature": node.metadata]
            if let cases = node.caseMetadata { metadata["cases"] = cases }
            return .description(.object(metadata))
        case .count:
            guard let count = node.count else { return failure("Selected value is not a collection or optional.") }
            return .count(.init(title: node.title, count: count, memberCount: memberCount, state: state))
        case .keys:
            if node.kind == .absent { return .status(.unset) }
            guard node.kind.isCollection else { return failure("Selected field is not a collection.") }
            return .keys(memberKeys(node))
        case .children:
            let children: [SBJSemanticReadResult.Child]
            if node.kind.isCollection {
                let counts = Dictionary(node.children.map { ($0.dictionaryKey ?? $0.title, 1) }, uniquingKeysWith: +)
                children = node.children.map { child in
                    let name = child.dictionaryKey ?? child.title
                    return .member(key: name, title: name == child.title ? nil : child.title,
                                   ordinal: child.position, ambiguous: counts[name, default: 0] > 1)
                }
            } else {
                children = immediate(path).compactMap { child in
                    guard let step = child.path.last, select(step, from: node) != nil else { return nil }
                    return .field(id: child.id, title: child.title)
                }
            }
            let start = min(max(0, childrenOffset), children.count)
            let page = children.dropFirst(start).prefix(max(1, childrenLimit ?? children.count))
            let end = start + page.count
            return .children(.init(title: node.title, members: Array(page), total: children.count,
                                   nextOffset: end < children.count ? end : nil, state: state, memberCount: memberCount))
        }
    }

	public var paths: [String] { entries.map(\.path) }
	private static func path(_ parent: String, _ component: String) -> String {
		parent + "/" + component.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
	}

	private static func typeName(_ type: Any.Type) -> String {
		switch SBJStructuralType.container(of: type) {
		case .optional(let wrapped)?: return typeName(wrapped) + "?"
		case .array(let element)?: return "[\(typeName(element))]"
		case .set(let element)?: return "Set<\(typeName(element))>"
		case .dictionary(let key, let value)?: return "[\(typeName(key)):\(typeName(value))]"
		case nil: return String(describing: type)
		}
	}

	private static func typeNomenclature(_ type: Any.Type) -> SBJNomenclature? {
		if case .optional(let wrapped)? = SBJStructuralType.container(of: type) { return typeNomenclature(wrapped) }
		return (type as? any SBJNomenclatureProviding.Type)?.nomenclature
	}

	private static let memberNameKey = "$memberName"

	private static func addMemberName(to node: inout Node, title: String) {
		guard node.kind == .object || node.kind == .associatedEnum else { return }
		guard !node.children.contains(where: { $0.name == "name" }) else { return }
		// Use a reserved internal path that cannot collide with a Swift property.
		node.children.append(.init(path: path(node.path, memberNameKey), name: memberNameKey,
								   title: "name", swiftType: "String", kind: .scalar,
								   description: "Name identifying this collection member", value: .text(title), children: []))
	}

	private static func memberTitle(_ value: Any, type: Any.Type, hints: [SBJPropertyHint]) -> String? {
		if case .optional(let wrapped)? = SBJStructuralType.container(of: type),
		   let container = value as? any SBJStructuralValueContainer {
			guard let child = container.sbjStructuralChildren(itemTitleKey: nil, itemIdentifierKey: nil).first else { return nil }
			return memberTitle(child.value, type: wrapped, hints: hints)
		}
		if let label = SBJCollectionItemIdentification.configuredTitle(for: value, itemTitleKey: SBJStructuralCollectionKeys.title(in: hints)) { return label }
		if let label = SBJCollectionItemIdentification.declaredName(for: value) { return label }
		if let label = (value as? any SBJTextPresentable)?.presentedValue, !label.isEmpty { return label }
		return nil
	}

	private static func build(_ value: Any, type: Any.Type, path: String, name: String, title: String,
							  description: String, constraints: [SBJPropertyConstraint], hints: [SBJPropertyHint], depth: Int) throws -> Node {
		guard depth < 128 else { throw SBJSemanticReadError.graphTooDeep(path) }
		var type = type
		var value = value
		let declaredType = typeName(type)
		let optionalCount = SBJStructuralType.optionalPresence(of: value).count
		// Optional wrappers have no address of their own. Nil is a real value,
		// not an empty collection, a zero, or an unavailable field.
		while case .optional(let wrapped)? = SBJStructuralType.container(of: type) {
			guard let container = value as? any SBJStructuralValueContainer,
				  let child = container.sbjStructuralChildren(itemTitleKey: nil, itemIdentifierKey: nil).first else {
				return .init(path: path, name: name, title: title, swiftType: declaredType, kind: .absent,
							 description: description, value: .null, children: [], nomenclature: typeNomenclature(type), optionalCount: optionalCount, hasContent: false)
			}
			value = child.value
			type = wrapped
		}
		let contentPresence = (value as? any HasContentCheckable)?.hasContent
		func node(_ kind: Node.Kind, value: SBJSemanticValue? = nil, children: [Node] = []) -> Node {
			var result = Node(path: path, name: name, title: title, swiftType: declaredType, kind: kind,
							  description: description, value: value, children: children, nomenclature: typeNomenclature(type),
							  optionalCount: optionalCount, hasContent: contentPresence)
			if let enumeration = type as? any SBJEnumCaseIdentifiable.Type {
				result.caseMetadata = .array(enumeration.sbjCaseNames.map { name in
					let info = enumeration.sbjCaseNomenclature(for: name)
					return .object(["name": .text(name), "title": .text(info?.nonEmptyTitle ?? name),
									"summary": info?.summary.map(SBJSemanticValue.text) ?? .null,
									"details": info?.details.map(SBJSemanticValue.text) ?? .null,
									"aliases": .array((info?.aliases ?? []).map(SBJSemanticValue.text))])
				})
			}
			return result
		}

		if let atomic = value as? any SBJAtomicStructuralValue {
			return node(.scalar, value: .text(atomic.presentedValue))
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
										 title: isSet ? "Member \(index + 1)" : "Item \(index + 1)",
										 description: SBJSemanticDescription.join([SBJSemanticDescription.type(elementType), SBJSemanticDescription.rules(projection.collectionElement.constraints)]),
										 constraints: projection.collectionElement.constraints, hints: [], depth: depth + 1)
					if let label = memberTitle(child.value, type: elementType, hints: hints), !label.isEmpty {
                        item.title = label
                        item.hasMemberTitle = true
                    } else if let label = SBJSemanticScalarReading.value(child.value, type: elementType)?.label { item.title = label }
					// Array positions are semantic; set traversal positions are not.
					item.position = isSet ? nil : index + 1
					addMemberName(to: &item, title: item.title)
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
					guard let key = child.dictionaryKey else { throw SBJSemanticReadError.inconsistentPayload("Dictionary key at \(path), entry \(index)") }
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
					var valueNode = try build(child.value, type: valueType, path: Self.path(entryPath, "value"), name: "value", title: "Value",
											  description: SBJSemanticDescription.join([SBJSemanticDescription.type(valueType), SBJSemanticDescription.rules(projection.dictionaryValue.constraints)]),
											  constraints: projection.dictionaryValue.constraints, hints: [], depth: depth + 1)
					let title = memberTitle(child.value, type: valueType, hints: hints) ?? label ?? "Entry \(index + 1)"
					addMemberName(to: &valueNode, title: title)
					return Node(path: entryPath, name: component, title: title, swiftType: "Entry<\(typeName(keyType)),\(typeName(valueType))>",
								kind: .entry, description: "Dictionary entry with typed key and value.", value: nil,
								children: [keyNode, valueNode], nomenclature: typeNomenclature(valueType), dictionaryKey: label)
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
		try SBJStructuralTraversal.definition(of: Root.self).filter { $0.metadata.isUserFacing }.map { declaration in
			let property = declaration.metadata
			var child = try build(property.value(in: root), type: property.valueType, path: path(parent, property.sourceName),
								  name: property.sourceName, title: property.displayName,
								  description: SBJSemanticDescription.property(property), constraints: property.constraints, hints: property.hints, depth: depth)
			child.nomenclature = property.info ?? child.nomenclature
			return child
		}
	}

	private static func associatedChildren<Root: SBJStructuredEnum>(_ root: Root, parent: String, depth: Int) throws -> [Node] {
		let caseName = root.sbjCaseName
		let info = Root.sbjCaseNomenclature(for: caseName)
		let tag = Node(path: path(parent, "caseName"), name: "caseName", title: "Active case", swiftType: "String", kind: .scalar,
					   description: SBJSemanticDescription.join(["Source-level enum case", SBJSemanticDescription.nomenclature(info)]), value: .text(caseName), children: [], nomenclature: info)
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
						   description: SBJSemanticDescription.nomenclature(info), value: nil, children: payload, nomenclature: info)]
	}
}
