import Foundation
import Observation

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
public struct SBJAIAssistantDocument<Root> {
    public let id: String
    public let revision: Int
    public let model: Root
    public let allowsEditing: Bool

    public init(id: String, revision: Int, model: Root, allowsEditing: Bool) {
        self.id = id
        self.revision = revision
        self.model = model
        self.allowsEditing = allowsEditing
    }
}
