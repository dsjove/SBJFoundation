import Foundation
#if os(iOS) || os(macOS)
import AVFoundation
#endif

struct CameraAvailability {
    let present: Set<CameraPosition>

    var hasAny: Bool { !present.isEmpty }
    var hasOptions: Bool { present.count > 1 }

    init(present: Set<CameraPosition> = []) {
        self.present = present
    }

    #if os(iOS) || os(macOS)
    static func discover() -> CameraAvailability {
        var present = Set<CameraPosition>()

        #if os(iOS) && !targetEnvironment(macCatalyst)
        if ProcessInfo.processInfo.isiOSAppOnMac {
            // Designed-for-iPad apps run as iOS binaries, but the available
            // capture device is Mac hardware and commonly has an unspecified
            // position. Use the same discovery policy as the Mac variants.
            if let device = AVCaptureDevice.default(for: .video) {
                present.insert(CameraPosition(native: device.position))
            }
        } else {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            for device in discovery.devices {
                present.insert(CameraPosition(native: device.position))
            }
        }
        #else
        // Native macOS and Mac Catalyst cameras commonly report an unspecified
        // position. AVCaptureDevice.default(for:) is the reliable cross-Mac path.
        if let device = AVCaptureDevice.default(for: .video) {
            present.insert(CameraPosition(native: device.position))
        }
        #endif

        return .init(present: present)
    }
    #else
    static func discover() -> CameraAvailability { .init() }
    #endif
}

public enum CameraPosition: Int, SBJFoundationType, Sendable {
    case unspecified = 0
    case back = 1
    case front = 2

    func supported(by availability: CameraAvailability) -> Bool {
        availability.present.contains(self)
    }

    func validated(by availability: CameraAvailability) -> CameraPosition {
        if supported(by: availability) { return self }
        if availability.present.contains(.back) { return .back }
        if availability.present.contains(.front) { return .front }
        if availability.present.contains(.unspecified) { return .unspecified }
        return .unspecified
    }

    func next(by availability: CameraAvailability) -> CameraPosition {
        let ordered: [CameraPosition] = [.back, .front, .unspecified]
        let available = ordered.filter { availability.present.contains($0) }
        guard !available.isEmpty else { return .unspecified }
        guard let index = available.firstIndex(of: self) else { return available[0] }
        return available[(index + 1) % available.count]
    }

    #if os(iOS) || os(macOS)
    init(native: AVCaptureDevice.Position?) {
        switch native {
        case .back: self = .back
        case .front: self = .front
        default: self = .unspecified
        }
    }

    var native: AVCaptureDevice.Position {
        switch self {
        case .back: .back
        case .front: .front
        case .unspecified: .unspecified
        }
    }

    var cameraDevice: AVCaptureDevice? {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return AVCaptureDevice.default(for: .video)
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: native
        )
        return discovery.devices.first
        #else
        return AVCaptureDevice.default(for: .video)
        #endif
    }
    #endif
}
