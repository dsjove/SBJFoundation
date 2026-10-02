import Foundation

/// Describes how one designated initializer parameter maps to a stored property.
public struct SBJSwiftInitializerParameter: Sendable, Equatable {
    public let propertyName: String
    public let label: String?
    /// Source spelling of the initializer parameter's default value, when present.
    /// Used only to decide whether that argument may be omitted from generated Swift.
    public let defaultExpression: String?

    public init(
        propertyName: String,
        label: String?,
        defaultExpression: String? = nil
    ) {
        self.propertyName = propertyName
        self.label = label
        self.defaultExpression = defaultExpression
    }
}

/// One initializer argument in a generated Swift construction expression.
public struct SBJSwiftArgument {
    public let label: String?
    public let expression: String
    public let summary: String?
    let matchesDefault: Bool

    public init(label: String?, expression: String, summary: String? = nil) {
        self.label = label
        self.expression = expression
        self.summary = summary
        self.matchesDefault = false
    }

    init(
        label: String?,
        expression: String,
        summary: String?,
        matchesDefault: Bool
    ) {
        self.label = label
        self.expression = expression
        self.summary = summary
        self.matchesDefault = matchesDefault
    }
}


/// Exports populated `@SBJStructure` values as reconstructable Swift source.
///
/// This first version deliberately uses fixed formatting. Formatting policy can
/// be added independently after the source-generation behavior is validated.
public struct SBJSwiftEncoder {
    public init() {}

    /// Produces a named declaration such as `let sample = Model(...)`.
    public func encode<T: SBJStructured>(_ value: T, named name: String) -> String {
        "let \(name.swiftIdentifier) = \(expression(for: value, nested: false))"
    }

    /// General value export. `SBJStructured` values use their structural metadata;
    /// other custom values fall back to reflection.
    public func expression<Value>(for value: Value, nested: Bool = true) -> String {
        expression(forAny: value, nested: nested)
    }

    func argument(
        _ value: Any,
        label: String?,
        info: SBJPropertyInfo?
    ) -> SBJSwiftArgument {
        let summary = info?.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return SBJSwiftArgument(
            label: label,
            expression: expression(forAny: value, nested: true),
            summary: summary?.isEmpty == false ? summary : nil
        )
    }

    func argument(
        _ value: Any,
        parameter: SBJSwiftInitializerParameter,
        info: SBJPropertyInfo?
    ) -> SBJSwiftArgument {
        let expression = expression(forAny: value, nested: true)
        let summary = info?.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return SBJSwiftArgument(
            label: parameter.label,
            expression: expression,
            summary: summary?.isEmpty == false ? summary : nil,
            matchesDefault: matchesDefault(
                value,
                expression: expression,
                defaultExpression: parameter.defaultExpression
            )
        )
    }

    private func matchesDefault(
        _ value: Any,
        expression: String,
        defaultExpression: String?
    ) -> Bool {
        guard let defaultExpression else { return false }
        let rendered = canonicalExpression(expression)
        let declared = canonicalExpression(defaultExpression)
        if rendered == declared { return true }

        // Empty collection defaults are commonly written as `.init()` even though
        // the clearer exported spelling is `[]` / `[:]`.
        if declared == ".init()" {
            let mirror = Mirror(reflecting: value)
            switch mirror.displayStyle {
            case .collection, .set, .dictionary:
                return mirror.children.isEmpty
            default:
                break
            }
        }
        return false
    }

    private func canonicalExpression(_ expression: String) -> String {
        expression.filter { !$0.isWhitespace }
    }

    func structuredExpression(
        typeName: String,
        nested: Bool,
        arguments: [SBJSwiftArgument]
    ) -> String {
        let constructor = nested ? ".init" : typeName
        let arguments = argumentsOmittingDefaults(arguments)
        guard !arguments.isEmpty else { return "\(constructor)()" }

        let body = arguments.map(render(argument:)).joined(separator: ",\n")
        return "\(constructor)(\n\(indent(body))\n)"
    }

    private func expression(forAny value: Any, nested: Bool) -> String {
        if let representable = value as? any SBJSwiftExpressionRepresentable {
            return representable.sbjSwiftExpression(using: self, nested: nested)
        }

        // Intentional built-in syntax table for Swift/Foundation primitives.
        // Custom SBJ/application value types must use
        // `SBJSwiftExpressionRepresentable` rather than adding concrete cases here.
        if let value = value as? String { return String(reflecting: value) }
        if let value = value as? Character { return String(reflecting: value) }
        if let value = value as? Bool { return value ? "true" : "false" }
        if let value = value as? Int { return String(value) }
        if let value = value as? Int8 { return String(value) }
        if let value = value as? Int16 { return String(value) }
        if let value = value as? Int32 { return String(value) }
        if let value = value as? Int64 { return String(value) }
        if let value = value as? UInt { return String(value) }
        if let value = value as? UInt8 { return String(value) }
        if let value = value as? UInt16 { return String(value) }
        if let value = value as? UInt32 { return String(value) }
        if let value = value as? UInt64 { return String(value) }
        if let value = value as? Float { return floatingPointExpression(value) }
        if let value = value as? Double { return floatingPointExpression(value) }
        if let value = value as? URL { return urlExpression(value) }
        if let value = value as? UUID { return "UUID(uuidString: \(String(reflecting: value.uuidString)))!" }
        if let value = value as? Date { return "Date(timeIntervalSinceReferenceDate: \(floatingPointExpression(value.timeIntervalSinceReferenceDate)))" }
        if let value = value as? Data { return dataExpression(value) }

        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .optional:
            guard let child = mirror.children.first else { return "nil" }
            return expression(forAny: child.value, nested: true)
        case .collection:
            return collectionExpression(mirror)
        case .set:
            return setExpression(mirror)
        case .dictionary:
            return dictionaryExpression(mirror)
        case .enum:
            return enumExpression(value, mirror: mirror)
        case .struct, .class:
            return reflectedInitializerExpression(value, mirror: mirror, nested: nested)
        case .tuple:
            return tupleExpression(mirror)
        case .none:
            return String(describing: value)
		case .some(.foreignReference):
            return String(describing: value)
		@unknown default:
            return String(describing: value)
        }
    }


    private func urlExpression(_ value: URL) -> String {
        if value.isFileURL {
            return "URL(fileURLWithPath: \(String(reflecting: value.path)))"
        }
        return "URL(string: \(String(reflecting: value.absoluteString)))!"
    }

    private func dataExpression(_ value: Data) -> String {
        guard !value.isEmpty else { return "Data()" }
        return "Data([\(value.map(String.init).joined(separator: ", "))])"
    }

    func floatingPointExpression<T: BinaryFloatingPoint>(_ value: T) -> String {
        if value.isNaN { return ".nan" }
        if value == .infinity { return ".infinity" }
        if value == -.infinity { return "-.infinity" }
        return String(describing: value)
    }

    private func collectionExpression(_ mirror: Mirror) -> String {
        let values = mirror.children.map { expression(forAny: $0.value, nested: true) }
        guard !values.isEmpty else { return "[]" }
        let body = values.joined(separator: ",\n")
        return "[\n\(indent(body))\n]"
    }

    private func setExpression(_ mirror: Mirror) -> String {
        let values = mirror.children.map { expression(forAny: $0.value, nested: true) }.sorted()
        guard !values.isEmpty else { return "[]" }
        let body = values.joined(separator: ",\n")
        return "[\n\(indent(body))\n]"
    }

    private func dictionaryExpression(_ mirror: Mirror) -> String {
        let entries: [String] = mirror.children.compactMap { child in
            let pair = Mirror(reflecting: child.value)
            let values = Array(pair.children)
            guard values.count == 2 else { return nil }
            let key = expression(forAny: values[0].value, nested: true)
            let value = expression(forAny: values[1].value, nested: true)
            return "\(key): \(value)"
        }
        guard !entries.isEmpty else { return "[:]" }
        let sortedEntries = entries.sorted()
        return "[\n\(indent(sortedEntries.joined(separator: ",\n")))\n]"
    }

    private func enumExpression(_ value: Any, mirror: Mirror) -> String {
        guard let payload = mirror.children.first else {
            if let structuredEnumType = type(of: value) as? any SBJStructuredEnum.Type,
               let caseName = structuredEnumType.sbjCaseName(for: value) {
                return ".\(caseName)"
            }
            if let rawRepresentable = value as? any RawRepresentable,
               let rawValue = rawRepresentable.rawValue as? String {
                let caseName = swiftEnumCaseIdentifier(from: rawValue)
                if isSwiftIdentifier(caseName) {
                    return ".\(caseName)"
                }
            }
            let describedCase = String(describing: value)
            return ".\(swiftEnumCaseIdentifier(from: describedCase))"
        }

        let described = String(describing: value)
        let caseName = payload.label
            ?? described.split(separator: "(", maxSplits: 1).first.map(String.init)
            ?? described
        let payloadMirror = Mirror(reflecting: payload.value)

        if payloadMirror.displayStyle == .tuple {
            let arguments = payloadMirror.children.map { child -> String in
                let expression = expression(forAny: child.value, nested: true)
                guard let label = child.label, !label.hasPrefix(".") else { return expression }
                return "\(label): \(expression)"
            }
            return enumCase(caseName, arguments: arguments)
        }

        return enumCase(
            caseName,
            arguments: [expression(forAny: payload.value, nested: true)]
        )
    }

    private func enumCase(_ name: String, arguments: [String]) -> String {
        guard !arguments.isEmpty else { return ".\(name)" }
        if arguments.count == 1, !arguments[0].contains("\n") {
            return ".\(name)(\(arguments[0]))"
        }
        return ".\(name)(\n\(indent(arguments.joined(separator: ",\n")))\n)"
    }

    private func swiftEnumCaseIdentifier(from rawValue: String) -> String {
        guard let first = rawValue.first else { return rawValue }
        return first.lowercased() + rawValue.dropFirst()
    }

    private func isSwiftIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let scalars = value.unicodeScalars
        guard let first = scalars.first,
              CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first)
        else { return false }

        let remainder = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return scalars.dropFirst().allSatisfy { remainder.contains($0) }
    }

    private func reflectedInitializerExpression(_ value: Any, mirror: Mirror, nested: Bool) -> String {
        let reflectedType = String(reflecting: Swift.type(of: value))
        let typeName = reflectedType.split(separator: ".").last.map(String.init)
            ?? String(describing: Swift.type(of: value))
        let constructor = nested ? ".init" : typeName
        let arguments = mirror.children.compactMap { child -> String? in
            guard let label = child.label else { return nil }
            let expression = expression(forAny: child.value, nested: true)
            return "\(label): \(expression)"
        }
        guard !arguments.isEmpty else { return "\(constructor)()" }
        return "\(constructor)(\n\(indent(arguments.joined(separator: ",\n")))\n)"
    }

    private func tupleExpression(_ mirror: Mirror) -> String {
        let elements = mirror.children.map { child -> String in
            let expression = expression(forAny: child.value, nested: true)
            guard let label = child.label, !label.hasPrefix(".") else { return expression }
            return "\(label): \(expression)"
        }
        return "(\(elements.joined(separator: ", ")))"
    }

    private func argumentsOmittingDefaults(
        _ arguments: [SBJSwiftArgument]
    ) -> [SBJSwiftArgument] {
        var keep = Array(repeating: false, count: arguments.count)
        var laterUnlabeledArgumentMustBeEmitted = false

        for index in arguments.indices.reversed() {
            let argument = arguments[index]
            if let _ = argument.label {
                keep[index] = !argument.matchesDefault
            } else if !argument.matchesDefault || laterUnlabeledArgumentMustBeEmitted {
                // An unlabeled default cannot be skipped when a later unlabeled
                // parameter is emitted; doing so would shift positional arguments.
                keep[index] = true
                laterUnlabeledArgumentMustBeEmitted = true
            }
        }

        return zip(arguments, keep).compactMap { argument, shouldKeep in
            shouldKeep ? argument : nil
        }
    }

    private func render(argument: SBJSwiftArgument) -> String {
        var lines: [String] = []
        if let summary = argument.summary {
            lines.append(contentsOf: summary
                .split(whereSeparator: \.isNewline)
                .map { "// \($0.trimmingCharacters(in: .whitespaces))" })
        }

        let value = argument.expression
        if let label = argument.label {
            lines.append("\(label): \(value)")
        } else {
            lines.append(value)
        }
        return lines.joined(separator: "\n")
    }

    private func indent(_ value: String) -> String {
        value.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "\t\($0)" }
            .joined(separator: "\n")
    }
}
