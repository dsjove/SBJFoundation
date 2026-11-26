import Foundation

/// Repeated compound types share templates. Distinct types may share the same
/// template when their compressed child definitions match exactly. Read targets
/// and occurrence-specific metadata remain independent.
enum SBJCompactStructure {
	struct TemplateKey: Hashable {
		let body: String
	}

	struct Node {
		let identifier: Int
		let label: String
		let children: [Node]
		let body: String
		let structuralType: ObjectIdentifier?
		var templateKey: TemplateKey? {
			guard structuralType != nil, !children.isEmpty else { return nil }
			return .init(body: body)
		}

		init(identifier: Int, label: String, children: [Node] = [], structuralType: ObjectIdentifier? = nil) {
			self.identifier = identifier
			self.label = label
			self.children = children
			self.structuralType = structuralType
			self.body = SBJCompactStructure.body(children.map { $0.expanded(includeIDs: false) })
		}

		func expanded(includeIDs: Bool = true) -> String {
			let head = (includeIDs ? String(identifier) : "") + label
			guard !children.isEmpty else { return head + ";" }
			return head + "{" + SBJCompactStructure.body(children.map { $0.expanded(includeIDs: includeIDs) }) + "}"
		}
	}

	/// The closing brace already terminates the final declaration.
	static func body(_ parts: [String]) -> String {
		let text = parts.joined()
		return text.hasSuffix(";") ? String(text.dropLast()) : text
	}

	/// Ordinary labels stay bare. Quote only labels that would otherwise be
	/// confused with delimiters, markers, IDs, or escape syntax.
	static func name(_ value: String) -> String {
		let reserved = CharacterSet(charactersIn: ",;{}@#[]():?+|*-\"\\")
		let needsQuotes = value.isEmpty || value.first?.isNumber == true
			|| value != value.trimmingCharacters(in: .whitespacesAndNewlines)
			|| value.unicodeScalars.contains { reserved.contains($0) || CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0) }
		guard needsQuotes else { return value }
		var result = "\""
		for scalar in value.unicodeScalars {
			switch scalar {
			case "\\": result += "\\\\"
			case "\"": result += "\\\""
			case "\n": result += "\\n"
			case "\r": result += "\\r"
			case "\t": result += "\\t"
			default:
				if CharacterSet.controlCharacters.contains(scalar) || CharacterSet.newlines.contains(scalar) {
					result += "\\u{\(String(scalar.value, radix: 16))}"
				} else {
					result.unicodeScalars.append(scalar)
				}
			}
		}
		return result + "\""
	}

	/// A declaration is allocated once in the consolidated graph. The original
	/// traversal keys are private occurrence keys, never model-facing IDs.
	struct Catalog {
		let compact: String
		let expanded: String
		let identifiers: [Int: Int]
		let declarationCount: Int
	}

	static func render(_ root: Node, usesTemplates: Bool = true) -> String {
		let catalog = catalog(root)
		return usesTemplates ? catalog.compact : catalog.expanded
	}

	static func catalog(_ root: Node) -> Catalog {
		var representatives: [TemplateKey: Node] = [:]
		var counts: [TemplateKey: Int] = [:]
		func collect(_ node: Node) {
			if let key = node.templateKey {
				if representatives[key] == nil { representatives[key] = node }
				counts[key, default: 0] += 1
			}
			node.children.forEach(collect)
		}
		collect(root)
		let repeated = Set(counts.filter { $0.value > 1 }.map(\.key))

		// Count references in the consolidated graph, not the expanded tree.
		// A child used only inside one shared parent definition is not duplicated.
		var references: [TemplateKey: Int] = [:]
		var visited = Set<TemplateKey>()
		func countReferences(_ node: Node) {
			if let key = node.templateKey, repeated.contains(key) {
				references[key, default: 0] += 1
				if visited.insert(key).inserted {
					representatives[key]!.children.forEach(countReferences)
				}
			} else {
				node.children.forEach(countReferences)
			}
		}
		countReferences(root)
		let selected = Set(references.filter { $0.value > 1 }.map(\.key))
		let definitions = selected.compactMap { representatives[$0] }.sorted {
			let lhs = $0.body.utf8.count, rhs = $1.body.utf8.count
			return lhs == rhs ? $0.identifier < $1.identifier : lhs < rhs
		}
		let numbers = Dictionary(uniqueKeysWithValues: definitions.enumerated().map { ($0.element.templateKey!, $0.offset + 1) })

		// Allocate IDs only for canonical declaration nodes. Map every original
		// occurrence to that ID so read resolution retains all paths and rules.
		var canonicalIDs: [Int: Int] = [:]
		var occurrenceIDs: [Int: Int] = [:]
		func assign(_ occurrence: Node, canonical: Node) {
			let id: Int
			if let existing = canonicalIDs[canonical.identifier] { id = existing }
			else {
				id = canonicalIDs.count + 1
				canonicalIDs[canonical.identifier] = id
			}
			occurrenceIDs[occurrence.identifier] = id
			let children: [Node]
			if let key = canonical.templateKey, selected.contains(key) {
				children = representatives[key]!.children
			} else { children = canonical.children }
			precondition(children.count == occurrence.children.count)
			for (actual, shared) in zip(occurrence.children, children) {
				assign(actual, canonical: shared)
			}
		}
		assign(root, canonical: root)

		func emit(_ node: Node, useReferences: Bool) -> String {
			let id = useReferences ? canonicalIDs[node.identifier]! : occurrenceIDs[node.identifier]!
			let head = String(id) + node.label
			if useReferences, let key = node.templateKey, let number = numbers[key] {
				return head + "#\(number);"
			}
			guard !node.children.isEmpty else { return head + ";" }
			return head + "{" + body(node.children.map { emit($0, useReferences: useReferences) }) + "}"
		}
		let templates = definitions.enumerated().map { index, node in
			"@\(index + 1){" + body(node.children.map { emit($0, useReferences: true) }) + "}"
		}.joined()
		return .init(compact: templates + emit(root, useReferences: true),
					 expanded: emit(root, useReferences: false),
					 identifiers: occurrenceIDs, declarationCount: canonicalIDs.count)
	}
}
