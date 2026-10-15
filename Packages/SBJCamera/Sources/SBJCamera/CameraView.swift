import SwiftUI

/// The SwiftUI facade for camera capture.
///
/// By default this view chooses the preferred available Apple-framework camera
/// implementation for the current platform. A concrete implementation can be
/// requested when an app wants a specific capture experience.
@MainActor
public struct CameraView: View {
    public typealias Completion = @MainActor (CapturedAttachment?) -> Void

    public static var isAvailable: Bool {
        CameraImplementation.preferred != nil
    }

    public static var availableImplementations: [CameraImplementation] {
        CameraImplementation.availableImplementations
    }

    private let implementation: CameraImplementation
    private let initialFlashMode: CameraFlashMode
    private let initialCameraPosition: CameraPosition
    private let allowsEditing: Bool
    private let remembersCameraDevice: Bool
    private let completion: Completion

    public init(
        implementation: CameraImplementation = .automatic,
        initialFlashMode: CameraFlashMode = .auto,
        initialCameraPosition: CameraPosition = .back,
        allowsEditing: Bool = false,
        remembersCameraDevice: Bool = true,
        completion: @escaping Completion
    ) {
        self.implementation = implementation
        self.initialFlashMode = initialFlashMode
        self.initialCameraPosition = initialCameraPosition
        self.allowsEditing = allowsEditing
        self.remembersCameraDevice = remembersCameraDevice
        self.completion = completion
    }

    public var body: some View {
        Group {
            switch implementation.resolved {
            case .some(.avFoundation):
                CameraCaptureView(
                    initialFlashMode: initialFlashMode,
                    initialCameraPosition: initialCameraPosition,
                    completion: completion
                )

            case .some(.systemPicker):
                SystemCameraPickerView(
                    allowsEditing: allowsEditing,
                    remembersCameraDevice: remembersCameraDevice,
                    completion: completion
                )

            case .some(.automatic), .none:
                ContentUnavailableView(
                    "Camera Unavailable",
                    systemImage: "camera.slash",
                    description: Text(unavailableDescription)
                )
            }
        }
    }

    private var unavailableDescription: String {
        switch implementation {
        case .automatic:
            "No supported camera implementation is available on this platform or device."
        case .avFoundation:
            "The AVFoundation camera implementation is not available on this platform or device."
        case .systemPicker:
            "The system camera picker is not available on this platform or device."
        }
    }
}
