import SBJLocalization

/// The camera's reusable controls, status messages, and accessibility
/// vocabulary. Runtime camera mode and error detail are kept separate.
public enum SBJCameraNomenclature: SBJNomenclatureSet {
    public static let all: [String: SBJNomenclature] = [
        "camera.cancel": .init(title: "Cancel", summary: "Close the camera without taking a photo.", symbol: .system("xmark.circle.fill")),
        "changeFlash": .init(title: "Change flash mode", summary: "Cycle through the available flash modes.", symbol: .system("bolt.badge.a.fill")),
        "switchCamera": .init(title: "Switch camera", summary: "Switch between available cameras.", symbol: .system("camera.rotate.fill")),
        "takePhoto": .init(title: "Take photo", summary: "Capture the current camera image.", symbol: .system("camera.circle")),
        "flashOff": .init(title: "Flash off", symbol: .system("bolt.slash.fill")),
        "flashOn": .init(title: "Flash on", symbol: .system("bolt.fill")),
        "flashAuto": .init(title: "Automatic flash", symbol: .system("bolt.badge.a.fill")),
        "torch": .init(title: "Torch", symbol: .system("flashlight.on.fill")),
        "unavailable": .init(title: "Camera Unavailable", summary: "Camera capture is not available on this platform.", symbol: .system("camera.slash")),
        "starting": .init(title: "Starting camera…", summary: "Initializing the camera."),
    ]
}
