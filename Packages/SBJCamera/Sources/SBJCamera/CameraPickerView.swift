#if !os(watchOS) && canImport(UIKit)
import Foundation
import SwiftUI

import UIKit

/// Compatibility wrapper that returns a captured `UIImage`.
///
/// Prefer ``CameraView`` when encoded capture data is useful. This wrapper exists
/// for callers that intentionally want a simple in-memory `UIImage` result.
@MainActor
public struct CameraPickerView: View {
    public typealias Completion = @MainActor (UIImage?) -> Void

    public static var isAvailable: Bool {
        #if targetEnvironment(macCatalyst)
        CameraCaptureView.isAvailable
        #elseif os(iOS)
        CameraImplementation.preferred != nil
        #else
        false
        #endif
    }

    private let allowsEditing: Bool
    private let remembersCameraDevice: Bool
    private let completion: Completion

    @Environment(\.dismiss) private var dismiss

    public init(
        image: Binding<UIImage?>,
        allowsEditing: Bool = false,
        remembersCameraDevice: Bool = true
    ) {
        self.allowsEditing = allowsEditing
        self.remembersCameraDevice = remembersCameraDevice
        self.completion = { capturedImage in
            guard let capturedImage else { return }
            image.wrappedValue = capturedImage
        }
    }

    public init(
        allowsEditing: Bool = false,
        remembersCameraDevice: Bool = true,
        completion: @escaping Completion
    ) {
        self.allowsEditing = allowsEditing
        self.remembersCameraDevice = remembersCameraDevice
        self.completion = completion
    }

    public var body: some View {
        Group {
            #if targetEnvironment(macCatalyst)
            CameraCaptureView { attachment in
                finish(attachment)
            }
            .ignoresSafeArea()
            #elseif os(iOS)
            CameraView(
                implementation: .automatic,
                allowsEditing: allowsEditing,
                remembersCameraDevice: remembersCameraDevice
            ) { attachment in
                finish(attachment)
            }
            .ignoresSafeArea()
            #else
            unavailableView
            #endif
        }
    }

    private var unavailableView: some View {
        ContentUnavailableView(
            "Camera Unavailable",
            systemImage: "camera.slash",
            description: Text("Camera capture is not available on this platform.")
        )
    }

    private func finish(_ attachment: CapturedAttachment?) {
        let image = attachment.flatMap { UIImage(data: $0.blob) }
        completion(image)
        dismiss()
    }
}
#endif
