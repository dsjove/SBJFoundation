/// Bounds-checked positional mutations for ordered collections.
/// These operations are independent of editor presentation.
public enum SBJArrayMutation {
    @discardableResult
    public static func move<Element>(from source: Int, to destination: Int, in values: inout [Element]) -> Bool {
        guard values.indices.contains(source), values.indices.contains(destination), source != destination else { return false }
        let element = values.remove(at: source)
        values.insert(element, at: destination)
        return true
    }

    @discardableResult
    public static func remove<Element>(at index: Int, from values: inout [Element]) -> Bool {
        guard values.indices.contains(index) else { return false }
        values.remove(at: index)
        return true
    }
}
