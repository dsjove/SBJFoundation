import Foundation

/// Broad measurement-system classification for reusable units.
///
/// This is semantic classification, not formatting policy. Whether a value is
/// shown as a fraction, decimal, compound measurement, abbreviation, and so on
/// belongs to presentation policy rather than to the measurement system itself.
@SBJStructure
public enum MeasurementSystem: String, Codable, Equatable, Sendable, CaseIterable, Hashable {
    case metric
    case imperial
    case universal
}
