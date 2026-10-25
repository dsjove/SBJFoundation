/// A strongly typed unit preference attached to structured-property metadata.
/// The concrete unit family remains explicit, preventing ambiguity across units
/// that happen to share the same case name.
public enum SBJDefaultUnit: Sendable, Equatable {
    case length(LengthUnit)
    case mass(MassUnit)
    case volume(VolumeUnit)
    case duration(DurationUnit)

    public init(_ unit: LengthUnit) { self = .length(unit) }
    public init(_ unit: MassUnit) { self = .mass(unit) }
    public init(_ unit: VolumeUnit) { self = .volume(unit) }
    public init(_ unit: DurationUnit) { self = .duration(unit) }
}
