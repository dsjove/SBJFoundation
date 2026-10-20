import Foundation
import SBJDataDefinition

@SBJStructure
public enum UnitCategory: String, Codable, Equatable, Sendable, CaseIterable, Hashable {
    case length
    case mass
    case duration
    case volume
}
