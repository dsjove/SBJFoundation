import Foundation

// These fundamental Codable enums are declared in Localization. All case
// identity and report/editor metadata stays at the DataDefinition layer.
public extension SBJEnumCaseIdentifiable where Self: CaseIterable & RawRepresentable, RawValue == String {
    static var sbjCaseNames: [String] { allCases.map(\.rawValue) }
    var sbjCaseName: String { rawValue }
}

public extension SBJStructuredEnum where Self: CaseIterable & RawRepresentable & Hashable, RawValue == String {
    static var sbjAssociatedCases: [SBJAssociatedCase<Self>] {
        allCases.map { candidate in
            .init(sourceName: candidate.rawValue,
                  matches: { $0 == candidate },
                  makeDefault: { candidate },
                  associatedValues: [])
        }
    }

    static func sbjCreateDefaultValueIfPossible() -> Self? { allCases.first }
    func sbjStructuralEquals(_ other: Self) -> Bool { self == other }
}

extension LengthUnit: SBJStructuredEnum {}
extension MassUnit: SBJStructuredEnum {}
extension VolumeUnit: SBJStructuredEnum {}
extension DurationUnit: SBJStructuredEnum {}
extension MeasurementSystem: SBJStructuredEnum {}
