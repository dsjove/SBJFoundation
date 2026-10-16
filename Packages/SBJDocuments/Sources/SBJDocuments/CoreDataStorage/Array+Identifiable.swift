import Foundation

public extension Array where Element: Identifiable {
    func nextIdentified(_ model: Element) -> Element? {
        if let index = identifiedIndex(model) {
            if count == 1 { return nil }
            if index < count - 1 { return self[index + 1] }
            return self[index - 1]
        }
        return last
    }

    func findIdentified(_ id: Element.ID?) -> Element? {
        guard let id else { return nil }
        return first { $0.id == id }
    }

    func containsIdentified(_ model: Element?) -> Bool {
        guard let model else { return false }
        return contains { $0.id == model.id }
    }

    func identifiedIndex(_ model: Element?) -> Index? {
        firstIndex { $0.id == model?.id }
    }

    @discardableResult
    mutating func addIdentified(_ model: Element) -> Bool {
        guard !containsIdentified(model) else { return false }
        append(model)
        return true
    }

    @discardableResult
    mutating func removeIdentified(_ model: Element) -> Bool {
        guard let index = identifiedIndex(model) else { return false }
        remove(at: index)
        return true
    }
}
