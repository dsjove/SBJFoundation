/// Mutable text being edited before it can necessarily be represented by a model value.
/// A failed parse changes only the draft, never the bound model value.
struct SBJParsedTextDraft {
    private(set) var text = ""
    private(set) var isValid = true

    mutating func edit<Value>(_ newText: String, parse: (String) -> Value?) -> Value? {
        text = newText
        let parsed = parse(newText)
        isValid = parsed != nil
        return parsed
    }

    mutating func reset(to formattedValue: String) {
        text = formattedValue
        isValid = true
    }
}
