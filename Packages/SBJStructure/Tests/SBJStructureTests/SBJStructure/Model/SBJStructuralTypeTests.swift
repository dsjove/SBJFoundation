import Testing
@testable import SBJStructure

@Test func structuralContainerTypesDoNotRequireInstances() throws {
    let dictionary = try #require(SBJStructuralType.container(of: [Int: [String?]].self))
    guard case .dictionary(let key, let value) = dictionary else {
        Issue.record("Expected dictionary")
        return
    }
    #expect(ObjectIdentifier(key) == ObjectIdentifier(Int.self))
    #expect(ObjectIdentifier(value) == ObjectIdentifier([String?].self))
    let array = try #require(SBJStructuralType.container(of: value))
    guard case .array(let element) = array else {
        Issue.record("Expected array")
        return
    }
    #expect(ObjectIdentifier(element) == ObjectIdentifier(String?.self))
    let optional = try #require(SBJStructuralType.container(of: element))
    guard case .optional(let wrapped) = optional else {
        Issue.record("Expected optional")
        return
    }
    #expect(ObjectIdentifier(wrapped) == ObjectIdentifier(String.self))
    let set = try #require(SBJStructuralType.container(of: Set<Int>.self))
    guard case .set(let member) = set else {
        Issue.record("Expected set")
        return
    }
    #expect(ObjectIdentifier(member) == ObjectIdentifier(Int.self))
    #expect(SBJStructuralType.container(of: Int.self) == nil)
}
