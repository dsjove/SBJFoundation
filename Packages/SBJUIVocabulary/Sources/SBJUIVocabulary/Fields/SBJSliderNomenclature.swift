import SBJLocalization

/// Shared vocabulary for transport and volume controls. Accessibility values
/// remain calculated from the current slider binding and its range.
public enum SBJSliderNomenclature: SBJNomenclatureSet {
    public static let all: [String: SBJNomenclature] = [
        "volume": .init(
            title: "Volume",
            summary: "Adjust the playback volume.",
            details: "Drag along the volume track or use the accessibility increment and decrement actions to change playback volume.",
            symbol: .system("speaker.wave.2")),
        "precision": .init(
            title: "Playback position",
            summary: "Adjust the playback position.",
            details: "Select a position on the graduated track or use the accessibility increment and decrement actions to seek through playback.",
            symbol: .system("slider.horizontal.3")),
    ]
}
