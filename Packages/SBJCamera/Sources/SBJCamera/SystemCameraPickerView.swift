import SwiftUI
import UniformTypeIdentifiers

#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit
#endif

/// SwiftUI access to Apple's system-provided still-camera interface.
///
/// This view deliberately represents only the UIImagePickerController camera
/// implementation. It compiles on every package platform and shows an
/// unavailable state where that implementation is not supported.
@MainActor
public struct SystemCameraPickerView: View {
    public typealias Completion = @MainActor (CapturedAttachment?) -> Void

    public static var isAvailable: Bool {
        CameraImplementation.systemPicker.isAvailable
    }

    private let allowsEditing: Bool
    private let remembersCameraDevice: Bool
    private let mirrorsFrontCameraPreview: Bool
    private let completion: Completion

    @Environment(\.dismiss) private var dismiss

    public init(
        allowsEditing: Bool = false,
        remembersCameraDevice: Bool = true,
        mirrorsFrontCameraPreview: Bool = true,
        completion: @escaping Completion
    ) {
        self.allowsEditing = allowsEditing
        self.remembersCameraDevice = remembersCameraDevice
        self.mirrorsFrontCameraPreview = mirrorsFrontCameraPreview
        self.completion = completion
    }

    public var body: some View {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if Self.isAvailable {
            SystemCameraPickerController(
                allowsEditing: allowsEditing,
                remembersCameraDevice: remembersCameraDevice,
                mirrorsFrontCameraPreview: mirrorsFrontCameraPreview
            ) { attachment in
                completion(attachment)
                dismiss()
            }
            .ignoresSafeArea()
        } else {
            unavailableView
        }
        #else
        unavailableView
        #endif
    }

    private var unavailableView: some View {
        ContentUnavailableView(
            "Camera Unavailable",
            systemImage: "camera.slash",
            description: Text("The system camera picker is not available on this platform or device.")
        )
    }
}

#if os(iOS) && !targetEnvironment(macCatalyst)
@MainActor
private struct SystemCameraPickerController: UIViewControllerRepresentable {
    let allowsEditing: Bool
    let remembersCameraDevice: Bool
    let mirrorsFrontCameraPreview: Bool
    let completion: SystemCameraPickerView.Completion

    private static let lastCameraDeviceKey = "SystemCameraPickerView.lastCameraDevice"

    func makeCoordinator() -> Coordinator {
        Coordinator(
            remembersCameraDevice: remembersCameraDevice,
            completion: completion
        )
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = allowsEditing
        picker.mediaTypes = [UTType.image.identifier]

        if let cameraDevice = Self.cameraDevice(remembersCameraDevice: remembersCameraDevice) {
            picker.cameraDevice = cameraDevice
        }

        Self.applyPreviewMirroring(
            to: picker,
            mirrorsFrontCameraPreview: mirrorsFrontCameraPreview
        )

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        Self.applyPreviewMirroring(
            to: uiViewController,
            mirrorsFrontCameraPreview: mirrorsFrontCameraPreview
        )
    }

    private static func applyPreviewMirroring(
        to picker: UIImagePickerController,
        mirrorsFrontCameraPreview: Bool
    ) {
        guard mirrorsFrontCameraPreview,
              picker.cameraDevice == .front else {
            picker.cameraViewTransform = .identity
            return
        }

        picker.cameraViewTransform = CGAffineTransform(scaleX: -1, y: 1)
    }

    private static func cameraDevice(remembersCameraDevice: Bool) -> UIImagePickerController.CameraDevice? {
        if remembersCameraDevice,
           let preferredDevice = loadPreferredCameraDevice(),
           UIImagePickerController.isCameraDeviceAvailable(preferredDevice) {
            return preferredDevice
        }

        if UIImagePickerController.isCameraDeviceAvailable(.rear) { return .rear }
        if UIImagePickerController.isCameraDeviceAvailable(.front) { return .front }
        return nil
    }

    private static func loadPreferredCameraDevice() -> UIImagePickerController.CameraDevice? {
        switch UserDefaults.standard.string(forKey: lastCameraDeviceKey) {
        case "front": return .front
        case "rear": return .rear
        default: return nil
        }
    }

    private static func savePreferredCameraDevice(_ device: UIImagePickerController.CameraDevice) {
        switch device {
        case .front:
            UserDefaults.standard.set("front", forKey: lastCameraDeviceKey)
        case .rear:
            UserDefaults.standard.set("rear", forKey: lastCameraDeviceKey)
        @unknown default:
            return
        }
    }

    @MainActor
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let remembersCameraDevice: Bool
        let completion: SystemCameraPickerView.Completion

        init(
            remembersCameraDevice: Bool,
            completion: @escaping SystemCameraPickerView.Completion
        ) {
            self.remembersCameraDevice = remembersCameraDevice
            self.completion = completion
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            rememberCameraDevice(from: picker)

            guard let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage,
                  let data = image.jpegData(compressionQuality: 1.0) else {
                completion(nil)
                return
            }

            completion(
                CapturedAttachment(
                    blob: data,
                    utiType: UTType.jpeg.identifier
                )
            )
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            rememberCameraDevice(from: picker)
            completion(nil)
        }

        private func rememberCameraDevice(from picker: UIImagePickerController) {
            guard remembersCameraDevice else { return }
            SystemCameraPickerController.savePreferredCameraDevice(picker.cameraDevice)
        }
    }
}
#endif
