import Foundation
import SBJDataDefinition
import SBJLocalization

/// A strongly typed unit that delegates physical conversion to Foundation's
/// `Dimension` / `Measurement` infrastructure.
///
/// Applications may define their own unit enums (for example game rounds) by
/// conforming to this protocol. Unit identity and conversion belong here;
/// editing increments and domain-specific preferred units do not.
public protocol UnitType: Codable, Sendable, CaseIterable, Hashable, Identifiable, StringPresentable {
    associatedtype FoundationUnit: Dimension

    var foundationUnit: FoundationUnit { get }
    var measurementSystem: MeasurementSystem { get }

    /// Transitional numeric presentation policy. Each conforming unit declares
    /// its own policy so generic infrastructure never needs to inspect unit type.
    var numberFormat: UnitNumberFormat { get }
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
