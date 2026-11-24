# SBJCamera

`SBJCamera` provides SwiftUI camera capture, optional low-level AVFoundation camera controls, and encoded still-image results. Use `CameraView` for most applications; it selects an available camera implementation for the current device.

## Getting started

The **application target** must include a user-facing `NSCameraUsageDescription` before using the camera. The package cannot supply that privacy string for the app. The user must grant camera permission when prompted.

```swift
CameraView { attachment in
    guard let attachment else { return } // User cancelled.
    // Persist attachment.blob, using attachment.utiType for the format.
}
```

`CapturedAttachment` contains encoded image bytes (`blob`) and a Uniform Type Identifier (`utiType`). Both built-in capture paths currently produce JPEG data. Prefer saving this directly over decoding and recompressing an image. The completion callback receives `nil` on cancellation; low-level `Camera.capture(completion:)` returns a `Result` that can report capture failures.

Check `CameraView.isAvailable` before presenting camera functionality. This reports discoverable device support, **not** whether camera permission has already been granted. Camera authorization is requested when AVFoundation capture starts.

## Selecting a camera experience

`CameraView` defaults to `.automatic`, which prefers the system camera picker where UIKit makes it available (usually iPhone and iPad), then falls back to AVFoundation. Mac Catalyst and native macOS use AVFoundation. An iPad app running on Apple-silicon Mac can use either path according to UIKit-reported availability. A requested implementation that is unavailable displays an unavailable view rather than silently switching to a different implementation.

```swift
CameraView(implementation: .avFoundation) { attachment in
    // Uses the package's capture controls.
}
```

| API | Purpose |
| --- | --- |
| `CameraView` | Recommended SwiftUI capture facade; returns encoded `CapturedAttachment` |
| `CameraCaptureView` | Explicit AVFoundation camera interface and controls |
| `SystemCameraPickerView` | Explicit system `UIImagePickerController` interface on supported iOS devices |
| `CameraPickerView` | Image-decoding convenience wrapper that returns `UIImage` (UIKit) or `NSImage` (AppKit) |
| `CameraFactory.make()` and `Camera` | Lower-level camera management for custom capture interfaces |
| `CameraPreview` | Displays a compatible camera's AVFoundation preview |
| `FrontCameraFlash` | Coordinates a temporary white-screen illumination around a custom shutter action |

The `CameraView` options `allowsEditing` and `remembersCameraDevice` affect the **system picker only**. They do not add image editing or camera-device persistence to AVFoundation. The AVFoundation UI accepts initial `CameraPosition` and `CameraFlashMode` options. `FrontCameraFlash` must be integrated by a custom caller; it is not automatically used by `CameraView`.

`CameraPickerView` is available on iOS and macOS (including Catalyst). It decodes the encoded photo into a platform image, and returns `nil` on cancellation or if decoding fails. Its binding-based initializer does not overwrite the binding on cancellation.

## Application configuration by destination

| Destination | Capture | App configuration |
| --- | --- | --- |
| iOS / iPadOS | System picker or AVFoundation | `NSCameraUsageDescription` |
| Mac (Designed for iPad) | Runtime-dependent system picker or AVFoundation fallback | iOS app's `NSCameraUsageDescription` |
| Mac Catalyst | AVFoundation | `NSCameraUsageDescription`, plus Camera access in App Sandbox when sandboxed |
| Native macOS | AVFoundation | `NSCameraUsageDescription`, plus Camera access in App Sandbox when sandboxed |
| watchOS, tvOS, visionOS | Unavailable through this package | Do not present a camera action; no privacy key needed solely for linking the library |

Permission errors from the lower-level API include `CameraError.authorizationDenied` and `.authorizationRestricted`. Applications should explain how to enable camera access rather than repeatedly requesting authorization.

## Camera behavior and limitations

- The camera may not be present even when the OS supports capture, such as on a simulator or a device without a camera.
- The system picker owns its own camera controls and can optionally remember the last selected front or rear camera in `UserDefaults`.
- The AVFoundation interface supports selection among discoverable cameras, flash or torch modes where available, and preview mirroring for the front camera.
- AVFoundation uses `AVCaptureDevice.RotationCoordinator` when available to align the preview and encoded still-photo orientation with the capture device. Still-photo capture uses the coordinator's **capture** rotation angle, which may differ from the preview angle.
- `FrontCameraFlash.perform(_:)` displays a temporary illumination and invokes the caller's shutter action. `cancel()` turns the illumination off and prevents a still-pending shutter invocation. Overlapping calls supersede older ones; callers remain responsible for serializing actual camera capture requests.
- The built-in `CameraCaptureView` shows an error when startup or capture fails, but its completion does not return an error. Use lower-level `Camera.capture(completion:)` if your application needs to handle a typed capture failure.

## Package scope

`SBJCamera` captures still images. Editing, image documents, library imports, and downstream photo-menu behavior belong to consumers or other packages and are not part of this camera API.

## Apple documentation

- [Camera privacy key](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSCameraUsageDescription)
- [Camera entitlement](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.device.camera)
- [Choosing an AVFoundation capture device](https://developer.apple.com/documentation/avfoundation/choosing-a-capture-device)
