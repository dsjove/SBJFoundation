import Foundation

/// Broad measurement-system classification for reusable units.
///
/// This is semantic classification, not formatting policy. Whether a value is
/// shown as a fraction, decimal, compound measurement, abbreviation, and so on
/// belongs to presentation policy rather than to the measurement system itself.
@SBJStructure
public enum MeasurementSystem: String, SBJFoundationType, Sendable, CaseIterable, Hashable {
    case metric
    case imperial
    case universal
}

/// Reusable measurement dimensions supplied by SBJFoundation.
@SBJStructure
public enum UnitCategory: String, SBJFoundationType, Sendable, CaseIterable, Hashable {
    case length
    case mass
    case duration
    case volume
}

/// A strongly typed unit that delegates physical conversion to Foundation's
/// `Dimension` / `Measurement` infrastructure.
///
/// Applications may define their own unit enums (for example game rounds) by
/// conforming to this protocol. Unit identity and conversion belong here;
/// editing increments and domain-specific preferred units do not.
public protocol UnitType: Codable, Sendable, CaseIterable, Hashable, Identifiable {
    associatedtype FoundationUnit: Dimension

    var foundationUnit: FoundationUnit { get }
    var measurementSystem: MeasurementSystem { get }

    /// Transitional numeric presentation policy. Each conforming unit declares
    /// its own policy so generic infrastructure never needs to inspect unit type.
    var numberFormat: UnitNumberFormat { get }

    /// Temporary presentation vocabulary used by the pre-localization UI.
    /// The localization/presentation-resource design will replace this String
    /// boundary rather than making unit display names a permanent raw-string API.
    var displayName: String { get }
}

public extension UnitType {
    var id: Self { self }
    var symbol: String { foundationUnit.symbol }

    func format(value: Double) -> String {
        numberFormat.format(value)
    }

    func convert(_ value: Double, to other: Self) -> Double {
        Measurement(value: value, unit: foundationUnit)
            .converted(to: other.foundationUnit)
            .value
    }
}
