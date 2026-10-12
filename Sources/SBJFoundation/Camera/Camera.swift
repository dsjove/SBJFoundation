import Foundation
import Observation

public enum CameraError: LocalizedError, Sendable {
    case authorizationDenied
    case authorizationRestricted
    case noCameraAvailable
    case cannotAddCameraInput
    case cannotAddPhotoOutput
    case sessionStartFailed
    case captureAlreadyInProgress
    case jpegDataCreationFailed
    case torchUnavailable
    case torchConfigurationFailed
    case unsupportedPlatform

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            "Camera access was denied."
        case .authorizationRestricted:
            "Camera access is restricted."
        case .noCameraAvailable:
            "No camera is available."
        case .cannotAddCameraInput:
            "The camera could not be initialized."
        case .cannotAddPhotoOutput:
            "Photo capture could not be initialized."
        case .sessionStartFailed:
            "The camera could not be started."
        case .captureAlreadyInProgress:
            "A photo capture is already in progress."
        case .jpegDataCreationFailed:
            "The captured photo could not be saved as a JPEG image."
        case .torchUnavailable:
            "The light is unavailable on the selected camera."
        case .torchConfigurationFailed:
            "The camera light could not be configured."
        case .unsupportedPlatform:
            "Camera capture is not available on this platform."
        }
    }
}

/// The camera capability used by clients of SBJFoundation Camera.
///
/// The AVFoundation implementation remains private so the public API compiles
/// on every Apple platform, including platforms where ordinary still-camera
/// capture is unavailable to third-party apps.
public protocol Camera: AnyObject, Observable {
    var isAuthorized: Bool { get }
    var hasCamera: Bool { get }
    var hasCameraOptions: Bool { get }
    var hasFlash: Bool { get }
    /// True when the app should present its simulated front-camera flash for the next capture.
    /// Camera implementations that do not support simulated flash use the default `false`.
    var shouldUseSimulatedFlash: Bool { get }
    var cameraPosition: CameraPosition { get }
    var flashMode: CameraFlashMode { get }

    func start(
        initialFlashMode: CameraFlashMode,
        initialCameraPosition: CameraPosition
    ) async throws

    func stop()
    func poll()
    func capture(completion: @escaping @MainActor @Sendable (Result<CapturedAttachment, Error>) -> Void)
    func nextCameraPosition(requesting: CameraPosition?) async throws -> CameraPosition
    func nextFlashMode(requesting: CameraFlashMode?) async throws -> CameraFlashMode
}

public extension Camera {
    /// Default for camera implementations that do not provide a simulated display flash,
    /// such as share-extension cameras and unsupported-platform stubs.
    var shouldUseSimulatedFlash: Bool { false }

    func nextCameraPosition() async throws -> CameraPosition {
        try await nextCameraPosition(requesting: nil)
    }

    func nextFlashMode() async throws -> CameraFlashMode {
        try await nextFlashMode(requesting: nil)
    }
}

/// Creates the standard Apple-framework-backed camera implementation.
public enum CameraFactory {
    /// Creates the standard camera implementation.
    ///
    /// - Parameter simulatesFrontCameraFlash: Set to `true` when the app provides
    ///   a white-screen flash for the front camera. When enabled, the front camera
    ///   advertises `.on` and `.auto` flash modes even though it has no physical flash.
    public static func make(simulatesFrontCameraFlash: Bool = false) -> any Camera {
        #if os(iOS) || os(macOS)
        CameraModel(simulatesFrontCameraFlash: simulatesFrontCameraFlash)
        #else
        UnavailableCamera()
        #endif
    }
}

@Observable
private final class UnavailableCamera: Camera {
    var isAuthorized: Bool { false }
    var hasCamera: Bool { false }
    var hasCameraOptions: Bool { false }
    var hasFlash: Bool { false }
    var cameraPosition: CameraPosition { .unspecified }
    var flashMode: CameraFlashMode { .off }

    func start(
        initialFlashMode: CameraFlashMode,
        initialCameraPosition: CameraPosition
    ) async throws {
        throw CameraError.unsupportedPlatform
    }

    func stop() { }
    func poll() { }

    func capture(completion: @escaping @MainActor @Sendable (Result<CapturedAttachment, Error>) -> Void) {
        Task { @MainActor in
            completion(.failure(CameraError.unsupportedPlatform))
        }
    }

    func nextCameraPosition(requesting: CameraPosition?) async throws -> CameraPosition {
        throw CameraError.unsupportedPlatform
    }

    func nextFlashMode(requesting: CameraFlashMode?) async throws -> CameraFlashMode {
        throw CameraError.unsupportedPlatform
    }
}
