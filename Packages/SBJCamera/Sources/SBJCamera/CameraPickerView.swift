#if os(iOS) || os(macOS)
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
/// Native in-memory image returned from ``CameraPickerView`` on iOS and Mac Catalyst.
public typealias CameraPickerImage = UIImage
#elseif canImport(AppKit)
import AppKit
/// Native in-memory image returned from ``CameraPickerView`` on macOS.
public typealias CameraPickerImage = NSImage
#endif

/// Convenience camera picker returning an in-memory platform image.
///
/// Capture selection, permissions, camera controls and cancellation all use
/// ``CameraView``; only the final platform-image decode differs between
/// UIKit and AppKit. For encoded capture data, prefer ``CameraView`` directly.
@MainActor
public struct CameraPickerView: View {
    public typealias Completion = @MainActor (CameraPickerImage?) -> Void

    public static var isAvailable: Bool { CameraView.isAvailable }

    private let allowsEditing: Bool
    private let remembersCameraDevice: Bool
    private let completion: Completion

    @Environment(\.dismiss) private var dismiss

    public init(
        image: Binding<CameraPickerImage?>,
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
        CameraView(
            allowsEditing: allowsEditing,
            remembersCameraDevice: remembersCameraDevice
        ) { attachment in
            finish(attachment)
        }
        .ignoresSafeArea()
    }

    private func finish(_ attachment: CapturedAttachment?) {
        let image = attachment.flatMap { CameraPickerImage(data: $0.blob) }
        completion(image)
        dismiss()
    }
}
#endif
