import Foundation
import Testing
@testable import SBJStructuredAI

/// Independent test-only decoder: expand the model-facing grammar and compare
/// it against the canonical expanded tree, including shared IDs and labels.
enum SBJCompactStructureTestDecoder {
    private struct Element {
        let id: Int
        let label: String
        let children: [Element]
        let reference: Int?
    }

    private enum Failure: Error { case invalidSyntax, unknownTemplate, recursiveTemplate }

    private struct Parser {
        let characters: [Character]
        var index = 0
        var peek: Character? { index < characters.count ? characters[index] : nil }

        mutating func consume(_ character: Character) throws {
            guard peek == character else { throw Failure.invalidSyntax }
            index += 1
        }

        mutating func number() throws -> Int {
            let start = index
            while let c = peek, "0123456789".contains(c) { index += 1 }
            guard start < index, let number = Int(String(characters[start..<index])) else { throw Failure.invalidSyntax }
            return number
        }

        mutating func body() throws -> [Element] {
            try consume("{")
            var elements: [Element] = []
            if peek != "}" {
                elements.append(try element())
                while peek == ";" {
                    try consume(";")
                    elements.append(try element())
                }
            }
            try consume("}")
            return elements
        }

        mutating func element() throws -> Element {
            let start = index
            var quoted = false
            while let c = peek {
                if !quoted && c == ":" { break }
                if quoted && c == "\\" {
                    index += 1
                    guard peek != nil else { throw Failure.invalidSyntax }
                } else if c == "\"" { quoted.toggle() }
                index += 1
            }
            guard !quoted, start < index else { throw Failure.invalidSyntax }
            let title = String(characters[start..<index])
            try consume(":")
            let id = try number()
            var marker = ""
            if peek == "?" { try consume("?"); marker = "?" }
            guard let kind = peek, "+|:*-".contains(kind) else { throw Failure.invalidSyntax }
            try consume(kind)
            let label = marker + String(kind) + title
            if peek == "{" { return .init(id: id, label: label, children: try body(), reference: nil) }
            if peek == "#" {
                try consume("#")
                return .init(id: id, label: label, children: [], reference: try number())
            }
            return .init(id: id, label: label, children: [], reference: nil)
        }
    }

    static func expand(_ text: String) throws -> String {
        guard !text.isEmpty else { return "" }
        var parser = Parser(characters: Array(text))
        var templates: [Int: [Element]] = [:]
        let root = try parser.element()
        while parser.peek == "\n" {
            try parser.consume("\n")
            try parser.consume("@")
            let id = try parser.number()
            let body = try parser.body()
            guard templates.updateValue(body, forKey: id) == nil else { throw Failure.invalidSyntax }
        }
        guard parser.peek == nil else { throw Failure.invalidSyntax }
        var seen = Set<Int>()
        func validate(_ element: Element) throws {
            guard seen.insert(element.id).inserted else { throw Failure.invalidSyntax }
            if let reference = element.reference, templates[reference] == nil { throw Failure.unknownTemplate }
            for child in element.children { try validate(child) }
        }
        for body in templates.values { for element in body { try validate(element) } }
        try validate(root)
        guard seen == Set(1...seen.count) else { throw Failure.invalidSyntax }
        func emit(_ element: Element, active: Set<Int>) throws -> String {
            let head = SBJCompactStructure.head(element.label, id: String(element.id))
            var children = element.children
            var nextActive = active
            if let reference = element.reference {
                guard !active.contains(reference) else { throw Failure.recursiveTemplate }
                guard let definition = templates[reference], !definition.isEmpty else { throw Failure.unknownTemplate }
                children = definition
                nextActive.insert(reference)
            }
            if children.isEmpty { return head }
            return head + "{" + SBJCompactStructure.body(try children.map { try emit($0, active: nextActive) }) + "}"
        }
        return try emit(root, active: [])
    }
}

@Suite("Compact structural templates")
struct SBJCompactStructureTests {
    typealias Node = SBJCompactStructure.Node

    @Test func firstOccurrenceUsesSharedIDs() throws {
        func attack(_ id: Int, _ label: String) -> Node {
            .init(identifier: id, label: "+" + label, children: [
                .init(identifier: id + 1, label: "-Attack Bonus"),
                .init(identifier: id + 3, label: "-Damage Type"),
                .init(identifier: id + 4, label: "?-Range")
            ], structuralType: (id == 2 ? ObjectIdentifier(Int.self) : ObjectIdentifier(String.self)))
        }
        let root = Node(identifier: 1, label: "|Attacks", children: [attack(2, "First"), attack(10, "Second")])
        let compressed = SBJCompactStructure.render(root)
        #expect(compressed == "Attacks:1|{First:2+#1;Second:6+#1}\n@1{Attack Bonus:3-;Damage Type:4-;Range:5?-}")
        #expect(try SBJCompactStructureTestDecoder.expand(compressed) == SBJCompactStructure.render(root, usesTemplates: false))
        #expect(compressed.utf8.count < SBJCompactStructure.render(root, usesTemplates: false).utf8.count)
    }

    @Test func nestedTemplatesUseSharedDeclarations() throws {
        func equipment(_ id: Int, _ label: String) -> Node {
            .init(identifier: id, label: label, children: [
                .init(identifier: id + 2, label: "-Maximum carrying capacity"),
                .init(identifier: id + 3, label: "-Current equipment weight"),
                .init(identifier: id + 4, label: "-Equipment replacement value")
            ], structuralType: (id == 11 || id == 90 ? ObjectIdentifier(Int.self) : ObjectIdentifier(String.self)))
        }
        func group(_ id: Int, _ label: String) -> Node {
            .init(identifier: id, label: label, children: [
                equipment(id + 1, "+Equipment"),
                .init(identifier: id + 6, label: "-Total adjusted inventory cost"),
                .init(identifier: id + 7, label: "-Remaining carrying allowance")
            ], structuralType: (id == 10 ? ObjectIdentifier(Double.self) : ObjectIdentifier(Float.self)))
        }
        let root = Node(identifier: 1, label: "+Root", children: [group(10, "+First"), group(50, "+Second"), equipment(90, "+Other"), equipment(100, "+Spare")])
        let compressed = SBJCompactStructure.render(root)
        #expect(compressed.contains("Equipment:3+#1;"))
        #expect(compressed.contains("Second:9+#2"))
        #expect(try SBJCompactStructureTestDecoder.expand(compressed) == SBJCompactStructure.render(root, usesTemplates: false))
        #expect(SBJCompactStructure.render(root) == compressed)
    }

    @Test func differentOccurrenceKeysShareTemplatesButDifferentLabelsDoNot() throws {
        let root = Node(identifier: 1, label: "+Root", children: [
            .init(identifier: 2, label: "+A", children: [.init(identifier: 3, label: "-A sufficiently long property name")], structuralType: ObjectIdentifier(Int.self)),
            .init(identifier: 4, label: "+B", children: [.init(identifier: 6, label: "-A sufficiently long property name")], structuralType: ObjectIdentifier(String.self)),
            .init(identifier: 7, label: "+C", children: [.init(identifier: 8, label: "-A different sufficiently long property name")], structuralType: ObjectIdentifier(Double.self))
        ])
        let compressed = SBJCompactStructure.render(root)
        #expect(compressed.contains("A:2+#1"))
        #expect(compressed.contains("B:4+#1"))
        #expect(try SBJCompactStructureTestDecoder.expand(compressed) == SBJCompactStructure.render(root, usesTemplates: false))
    }

    @Test func identicalProjectedBodiesShareButUntypedSubtreesDoNot() throws {
        let label = "-A sufficiently long property name for compression"
        let root = Node(identifier: 1, label: "+Root", children: [
            .init(identifier: 2, label: "+A", children: [.init(identifier: 3, label: label)], structuralType: ObjectIdentifier(Int.self)),
            .init(identifier: 4, label: "+B", children: [.init(identifier: 5, label: label)], structuralType: ObjectIdentifier(String.self)),
            .init(identifier: 6, label: "+C", children: [.init(identifier: 7, label: label)]),
            .init(identifier: 8, label: "+D", children: [.init(identifier: 9, label: label)])
        ])
        let compressed = SBJCompactStructure.render(root)
        #expect(compressed.contains("A:2+#1"))
        #expect(compressed.contains("B:4+#1"))
        #expect(compressed.contains("C:5+{"))
        #expect(compressed.contains("D:7+{"))
        #expect(try SBJCompactStructureTestDecoder.expand(compressed) == SBJCompactStructure.render(root, usesTemplates: false))
    }

    @Test func repeatedSameTypeCreatesTemplate() throws {
        let type = ObjectIdentifier(Int.self)
        let root = Node(identifier: 1, label: "+Root", children: [2, 4, 6].map { id in
            .init(identifier: id, label: "+Health", children: [
                .init(identifier: id + 1, label: "?-Temporary Hit Points,THP")
            ], structuralType: type)
        })
        let compressed = SBJCompactStructure.render(root)
        #expect(compressed.contains("@1{Temporary Hit Points,THP:3?-}"))
        #expect(compressed.contains("Health:2+#1"))
        #expect(compressed.contains("Health:4+#1"))
        #expect(compressed.contains("Health:5+#1"))
        #expect(try SBJCompactStructureTestDecoder.expand(compressed) == SBJCompactStructure.render(root, usesTemplates: false))
    }

    @Test func shortRepeatedDefinitionStillCreatesTemplate() throws {
        let type = ObjectIdentifier(Int.self)
        let root = Node(identifier: 1, label: "+Root", children: [2, 4].map { id in
            .init(identifier: id, label: "+Rule", children: [
                .init(identifier: id + 1, label: "-V")
            ], structuralType: type)
        })
        let compressed = SBJCompactStructure.render(root)
        #expect(compressed.contains("@1{V:3-}"))
        #expect(compressed.contains("Rule:2+#1"))
        #expect(compressed.contains("Rule:4+#1"))
        #expect(try SBJCompactStructureTestDecoder.expand(compressed) == SBJCompactStructure.render(root, usesTemplates: false))
    }

    @Test func nestedTypeUsedOnlyInSharedParentIsNotSeparateTemplate() throws {
        func attack(_ id: Int) -> Node {
            .init(identifier: id, label: "+Attack", children: [
                .init(identifier: id + 1, label: "+Range", children: [
                    .init(identifier: id + 2, label: "-Distance")
                ], structuralType: ObjectIdentifier(String.self))
            ], structuralType: ObjectIdentifier(Int.self))
        }
        let root = Node(identifier: 1, label: "+Root", children: [attack(2), attack(5)])
        let catalog = SBJCompactStructure.catalog(root)
        #expect(catalog.compact == "Root:1+{Attack:2+#1;Attack:5+#1}\n@1{Range:3+{Distance:4-}}")
        #expect(catalog.declarationCount == 5)
        #expect(catalog.identifiers[3] == catalog.identifiers[6])
        #expect(catalog.identifiers[4] == catalog.identifiers[7])
        #expect(catalog.identifiers[2] != catalog.identifiers[5])
        #expect(try SBJCompactStructureTestDecoder.expand(catalog.compact) == catalog.expanded)
    }

    @Test func leavesNeverCreateTemplates() {
        let root = Node(identifier: 1, label: "+Root", children: [
            .init(identifier: 2, label: "?-Temporary Hit Points", structuralType: ObjectIdentifier(Int.self)),
            .init(identifier: 3, label: "?-Temporary Hit Points", structuralType: ObjectIdentifier(String.self))
        ])
        #expect(SBJCompactStructure.render(root) == root.expanded())
    }

    @Test func reservedPunctuationAndLeadingDigitsAreQuoted() throws {
        #expect(SBJCompactStructure.name("Max HP") == "Max HP")
        #expect(SBJCompactStructure.name("42 Gold") == "\"42 Gold\"")
        #expect(SBJCompactStructure.name("Name, #1; {x}") == "\"Name, #1; {x}\"")
        #expect(SBJCompactStructure.name("A\nB\"C\\D") == "\"A\\nB\\\"C\\\\D\"")
        let label = SBJCompactStructure.name("1;{#@\"}")
        let root = Node(identifier: 1, label: "+Root", children: [.init(identifier: 2, label: "-" + label), .init(identifier: 3, label: "|Empty"), .init(identifier: 4, label: "?-Absent")])
        #expect(try SBJCompactStructureTestDecoder.expand(SBJCompactStructure.render(root)) == SBJCompactStructure.render(root, usesTemplates: false))
    }
}
