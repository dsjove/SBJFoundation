import Foundation
import SwiftUI

#if os(iOS) || os(macOS)
import AVFoundation
#endif

#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit
#endif

/// Camera implementations exposed by SBJFoundation Camera.
///
/// Use ``automatic`` for the normal facade behavior, or select a concrete
/// implementation when an app specifically wants one of the available camera
/// experiences on the current platform.
public enum CameraImplementation: String, SBJFoundationType, CaseIterable, Sendable {
    /// Select the package's preferred available implementation for this platform.
    case automatic

    /// SBJFoundation Camera's AVFoundation capture session and SwiftUI controls.
    case avFoundation

    /// Apple's UIImagePickerController camera interface.
    ///
    /// This implementation is available for iPhone and iPad apps, but not for
    /// Mac Catalyst or native macOS camera capture.
    case systemPicker
}

@MainActor
public extension CameraImplementation {
    /// Whether this implementation can capture from a camera on this device.
    var isAvailable: Bool {
        switch self {
        case .automatic:
            return Self.preferred != nil

        case .avFoundation:
            return CameraCaptureView.isAvailable

        case .systemPicker:
            #if os(iOS) && !targetEnvironment(macCatalyst)
            // Designed-for-iPad on Apple-silicon Mac is still an iOS runtime.
            // Do not exclude it preemptively: if UIKit reports the camera source
            // available, prefer the system-owned capture UI there as well.
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return false }
            return UIImagePickerController.isCameraDeviceAvailable(.front)
                || UIImagePickerController.isCameraDeviceAvailable(.rear)
            #else
            return false
            #endif
        }
    }

    /// Concrete camera implementations currently usable on this device.
    static var availableImplementations: [CameraImplementation] {
        [.systemPicker, .avFoundation].filter(\.isAvailable)
    }

    /// The implementation selected by ``automatic``.
    ///
    /// iPhone and iPad prefer Apple's system camera interface because it owns
    /// the complete capture UI and device behavior. Mac Catalyst, native macOS,
    /// and iPad apps running on Apple-silicon Mac use AVFoundation. If the
    /// preferred implementation is unavailable, this falls back to any other
    /// available implementation.
    static var preferred: CameraImplementation? {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Prefer UIKit's system camera whenever it is available, including a
        // Designed-for-iPad app running on Apple-silicon Mac. The compatibility
        // environment can take a long time to initialize a custom AVCaptureSession,
        // while the system picker owns that lifecycle and orientation handling.
        if CameraImplementation.systemPicker.isAvailable { return .systemPicker }
        if CameraImplementation.avFoundation.isAvailable { return .avFoundation }
        return nil
        #elseif targetEnvironment(macCatalyst) || os(macOS)
        if CameraImplementation.avFoundation.isAvailable { return .avFoundation }
        return nil
        #else
        return nil
        #endif
    }

    /// Resolves ``automatic`` to a concrete implementation.
    var resolved: CameraImplementation? {
        switch self {
        case .automatic:
            Self.preferred
        default:
            isAvailable ? self : nil
        }
    }
}
