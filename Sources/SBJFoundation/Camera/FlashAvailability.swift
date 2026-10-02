#if os(iOS) || os(macOS)
import AVFoundation
#endif

struct FlashAvailability {
    let present: Set<CameraFlashMode>

    var hasFlash: Bool {
        present.contains(.on) || present.contains(.auto)
    }

    var hasTorch: Bool {
        present.contains(.torch)
    }

    init() {
        self.present = []
    }

    #if os(iOS) || os(macOS)
    init(
        device: AVCaptureDevice?,
        photoOutput: AVCapturePhotoOutput,
        simulatesFrontCameraFlash: Bool = false
    ) {
        var present = Set(
            photoOutput.supportedFlashModes.compactMap {
                switch $0 {
                case .auto: return CameraFlashMode.auto
                case .on: return CameraFlashMode.on
                case .off: return CameraFlashMode.off
                @unknown default: return nil
                }
            }
        )
        if let device {
            if device.hasTorch {
                present.insert(.torch)
            }

            // A front camera normally has no physical flash, so AVFoundation does
            // not advertise `.on` / `.auto`. Apps that provide a white-screen flash
            // can opt in and expose those modes as an app capability.
            if simulatesFrontCameraFlash, device.position == .front {
                present.insert(.off)
                present.insert(.on)
                present.insert(.auto)
            }
        }
        self.present = present
    }
    #endif
}

public enum CameraFlashMode: Int, SBJFoundationType, Sendable {
    case off = 0
    case on = 1
    case auto = 2
    case torch = 3

    var next: CameraFlashMode {
        CameraFlashMode(rawValue: rawValue + 1) ?? .off
    }

    func supported(by availability: FlashAvailability) -> Bool {
        availability.present.contains(self)
    }

    func validated(by availability: FlashAvailability) -> CameraFlashMode {
        var candidate = self
        repeat {
            if candidate.supported(by: availability) {
                return candidate
            }
            candidate = candidate.next
        } while candidate != self
        return .off
    }

    func next(by availability: FlashAvailability) -> CameraFlashMode {
        self.next.validated(by: availability)
    }

    #if os(iOS) || os(macOS)
    var nativeFlashMode: AVCaptureDevice.FlashMode? {
        switch self {
        case .off: .off
        case .on: .on
        case .auto: .auto
        case .torch: nil
        }
    }
    #endif
}
