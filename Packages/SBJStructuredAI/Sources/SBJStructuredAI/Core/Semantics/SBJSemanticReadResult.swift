import Foundation

/// Deterministic query outcomes. The model receives compact text, not a
/// dictionary of transport fields. SBJSemanticValue represents document data.
public enum SBJSemanticReadResult: Sendable, Equatable {
    public enum State: String, Sendable {
        case unset, inactive, missing, empty
    }

    public enum KeyAction: String, Sendable {
        case insert, replace
    }

    public struct MemberKey: Sendable, Equatable {
        public let key: String
        public let title: String?
    }

    public struct CollectionKeys: Sendable, Equatable {
        public let members: [MemberKey]
        public let unaddressableCount: Int
    }

    public struct MemberRequest: Sendable, Equatable {
        public let action: KeyAction
        public let keyPosition: Int
        public let collectionID: Int?
        public let available: CollectionKeys
        public let reason: String
    }

    public struct ReadValue: Sendable, Equatable {
        public let value: SBJSemanticValue
        public let title: String
        public let state: State?
        public let count: Int?
        public let memberCount: Int?
    }

    public struct Count: Sendable, Equatable {
        public let title: String
        public let count: Int
        public let memberCount: Int?
        public let state: State?
    }

    public enum Child: Sendable, Equatable {
        case field(id: Int, title: String)
        case member(key: String, title: String?, ordinal: Int?, ambiguous: Bool)
    }

    public struct Children: Sendable, Equatable {
        public let title: String
        public let members: [Child]
        public let total: Int
        public let nextOffset: Int?
        public let state: State?
        public let memberCount: Int?
    }

    case value(ReadValue)
    case keys(CollectionKeys)
    case memberRequired(MemberRequest)
    case status(State)
    case error(String)
    case description(SBJSemanticValue)
    // Internal semantic inspection operations, not registered model tools.
    case count(Count)
    case children(Children)
}

extension SBJSemanticReadResult {
    /// Tool output is a native String (PromptRepresentable). No JSON encoding,
    /// GeneratedContent construction or model-generated result schema is needed.
    var promptText: String {
        switch self {
        case .value(let read):
            if read.state == .unset { return "status:unset" }
            return "value:" + Self.render(read.value) + (read.state.map { ";status:" + $0.rawValue } ?? "")
        case .keys(let available):
            return Self.renderKeys(available)
        case .memberRequired(let request):
            return "memberRequired:\(request.action.rawValue):\(request.keyPosition);" + Self.renderKeys(request.available)
        case .status(let state): return "status:" + state.rawValue
        case .error(let message): return "error:" + Self.quoted(message)
        case .description(let data): return "description:" + Self.render(data)
        case .count, .children:
            // Neither operation is exposed by the registered tools.
            return "error:" + Self.quoted(SBJAIInstructions.unsupportedOperation)
        }
    }

    private static func renderKeys(_ available: CollectionKeys) -> String {
        let members = available.members.map { member in
            key(member.key) + (member.title.map { "=" + key($0) } ?? "")
        }.joined(separator: ",")
        return "keys:" + members + (available.unaddressableCount > 0 ? ";unaddressable:\(available.unaddressableCount)" : "")
    }

    private static func key(_ value: String) -> String {
        let reserved = CharacterSet(charactersIn: ",;=:\"\\[]{}")
        if value.isEmpty || value != value.trimmingCharacters(in: .whitespacesAndNewlines)
            || value.unicodeScalars.contains(where: { reserved.contains($0) || CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0) }) {
            return quoted(value)
        }
        return value
    }

    static func render(_ value: SBJSemanticValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let value): return String(value)
        case .signed(let value): return String(value)
        case .unsigned(let value): return String(value)
        case .number(let value): return value.isFinite ? String(value) : quoted(String(value))
        case .decimal(let value):
            let decimal = NSDecimalNumber(decimal: value)
            return decimal == .notANumber ? quoted(decimal.stringValue) : decimal.stringValue
        case .text(let value): return quoted(value)
        case .array(let values): return "[" + values.map(render).joined(separator: ",") + "]"
        case .object(let fields):
            return "{" + fields.sorted { $0.key < $1.key }.map { quoted($0.key) + "=" + render($0.value) }.joined(separator: ";") + "}"
        }
    }

    private static func quoted(_ value: String) -> String {
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
                } else { result.unicodeScalars.append(scalar) }
            }
        }
        return result + "\""
    }
}
