# Camera

SBJFoundation's `Camera/` source folder contains the complete camera abstraction used by the framework. It merges the former standalone SBJCamera package with the camera picker previously embedded in `Image/`.

The camera layer deliberately separates capture from image editing:

- `CameraView` is the preferred high-level SwiftUI capture surface. It returns encoded `CapturedAttachment` data and chooses the most appropriate supported implementation.
- `CameraCaptureView` is the framework's AVFoundation implementation.
- `SystemCameraPickerView` is Apple's `UIImagePickerController` camera UI where that API is available.
- `CameraPickerView` is a compatibility convenience that returns an in-memory `UIImage` for callers that intentionally want that simpler API.
- `Camera`, `CameraModel`, `CameraPreview`, `CameraPosition`, and `CameraFlashMode` support custom camera experiences.
- `PhotoMenu` uses `CameraView` directly so a camera capture can remain encoded data and does not need an unnecessary UIImage decode/re-encode cycle.

## Project configuration

Camera privacy configuration belongs to the **application target**, not SBJFoundation. A Swift package cannot add an application's privacy usage strings, entitlements, or capabilities for it.

### iPhone and iPad (iOS / iPadOS)

Required when the app exposes camera capture:

1. Select the app target in Xcode.
2. Open **Info**.
3. Add **Privacy - Camera Usage Description** (`NSCameraUsageDescription`).
4. Give the value a user-facing reason, for example: `Take photos for character portraits.`

No camera entitlement is required for an ordinary iOS/iPadOS app.

`CameraView` normally prefers Apple's system camera picker on an iPhone or iPad and falls back to the AVFoundation implementation when appropriate.

### Mac (Designed for iPad)

A Mac (Designed for iPad) build is still an iOS application running on Apple-silicon Mac hardware. Configure it using the iOS privacy model:

1. Keep **Mac (Designed for iPad)** enabled under the target's supported destinations when that is a desired destination.
2. Add `NSCameraUsageDescription` to the iOS app target.
3. Do **not** add the macOS App Sandbox camera entitlement merely because the iPad app can run on Mac. A Designed-for-iPad app is not a Mac Catalyst or native macOS app.
4. The user grants/revokes access in macOS **System Settings > Privacy & Security > Camera**.

SBJFoundation detects `ProcessInfo.processInfo.isiOSAppOnMac` and uses the AVFoundation camera path rather than `UIImagePickerController`, because the Mac camera is not represented like an iPhone/iPad front/back camera pair.

A useful app-target setting is an explicit, non-empty **Bundle display name** (`CFBundleDisplayName`). If it is blank, macOS privacy UI can fall back to a bundle/application URL-like name; spaces may then be shown escaped as `%20` (for example `Jove's%20Characters.app`). This is cosmetic and does not indicate a camera-permission failure, but setting `CFBundleDisplayName` avoids that presentation.

### Mac Catalyst

Mac Catalyst is a distinct Mac target environment, not the same thing as Mac (Designed for iPad).

When camera capture is enabled for a Catalyst target:

1. Add **Privacy - Camera Usage Description** (`NSCameraUsageDescription`) to the app target.
2. In **Signing & Capabilities**, ensure **App Sandbox** is present.
3. Under App Sandbox hardware access, enable **Camera**. This supplies the `com.apple.security.device.camera` entitlement.
4. The user must also grant camera permission in macOS **System Settings > Privacy & Security > Camera**.

`CameraView` uses the AVFoundation implementation for Catalyst.

### Apple TV (tvOS)

SBJFoundation compiles on tvOS, but this camera layer does not currently implement Apple TV Continuity Camera capture. `CameraView.isAvailable` is therefore false and the camera UI resolves to an unavailable state.

For an app using only SBJFoundation's current camera layer:

- do not expose the camera action on tvOS;
- no camera privacy key or camera entitlement is required solely because SBJFoundation is linked.

If an application independently implements a tvOS Continuity Camera workflow, follow the requirements of the Apple API used by that implementation; that is outside this framework's current camera support.

### Apple Watch (watchOS)

Apple Watch does not provide an ordinary local still-camera capture device to this framework. SBJFoundation compiles on watchOS, but camera capture is unavailable and `CameraView.isAvailable` is false.

For an app using only SBJFoundation's camera layer:

- do not expose the camera action on watchOS;
- no `NSCameraUsageDescription` is required merely because the package is linked.

A Watch app that remotely controls an iPhone camera is a different feature and is not implemented by this camera layer.

## Privacy authorization behavior

The AVFoundation implementation requests video-capture authorization only when capture starts. Applications should not request camera access preemptively just because a screen containing `PhotoMenu` or `CameraView` exists.

The possible authorization failures are surfaced as `CameraError.authorizationDenied` or `CameraError.authorizationRestricted`.

The system owns the user's privacy decision. Deleting/reinstalling an app, changing its bundle identifier, or resetting privacy permissions can cause the system to ask again.

## Choosing an implementation

For most applications:

```swift
CameraView { attachment in
    // attachment.blob contains encoded image data.
    // attachment.utiType identifies the encoding.
}
```

Use a specific implementation only when the application has a reason to choose one:

```swift
CameraView(implementation: .avFoundation) { attachment in
    // Custom SBJFoundation capture UI.
}
```

or on supported iPhone/iPad devices:

```swift
CameraView(implementation: .systemPicker) { attachment in
    // Apple's system UIImagePickerController camera UI.
}
```

For a deliberately simple in-memory image workflow, the compatibility wrapper remains available:

```swift
CameraPickerView { image in
    // UIImage? result
}
```

## PhotoMenu integration

`PhotoMenu` uses the camera layer without requiring an application to know which implementation is active. Camera capture is accepted as encoded `SBJResourceContent` and then follows the same import/edit path as Photos, Files, and Paste.

Applications that want ordinary destructive editing can continue using the defaults.

`PhotoMenu` does not carry a separate edit-preservation flag. It infers behavior from the resource returned by its binding: ordinary images use the simple destructive/in-memory path, while an `SBJImageDocument` reopens its saved geometry, color state, and markup. A model that requires non-destructive resources should normalize assigned images with `SBJResourceContent.preservingImageEdits`; camera imports then enter the editor as complete image documents and later **Edit** operations reopen the saved state.

## Apple references

- `NSCameraUsageDescription`: https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSCameraUsageDescription
- Camera entitlement (`com.apple.security.device.camera`): https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.security.device.camera
- AVFoundation capture-device selection: https://developer.apple.com/documentation/avfoundation/choosing-a-capture-device
- Mac Catalyst configuration: https://developer.apple.com/documentation/uikit/creating-a-mac-version-of-your-ipad-app

### Mac (Designed for iPad) still-image orientation

A Designed-for-iPad app runs the iOS AVFoundation implementation on Mac. The camera is physically fixed to the Mac/display rather than rotating with an iPad. SBJFoundation therefore uses the rotation coordinator's horizon-level **preview** angle for `AVCapturePhotoOutput` still capture when `ProcessInfo.processInfo.isiOSAppOnMac` is true. This keeps the encoded photo orientation consistent with the upright live preview and prevents a 90-degree EXIF orientation mismatch when the photo is subsequently opened in `PhotoEditor`.

Other AVFoundation platforms continue to use `videoRotationAngleForHorizonLevelCapture` for still capture.


### Designed for iPad on Apple-silicon Mac

`CameraImplementation.automatic` first asks UIKit whether `UIImagePickerController.SourceType.camera` is available. If it is, SBJFoundation uses the system camera picker. This is preferred over constructing a custom `AVCaptureSession` in the iOS-on-Mac compatibility environment because the system controller owns camera startup, presentation, and still-image orientation.

If the system camera source is unavailable, SBJFoundation falls back to its AVFoundation implementation. The fallback uses `AVCaptureDevice.RotationCoordinator.videoRotationAngleForHorizonLevelCapture` for still capture and the separate preview angle for the preview layer.


- When the system camera picker is using the front camera, SBJFoundation mirrors the preview horizontally so the live and retake review behave more like a selfie camera. The stored captured image remains the picker's delivered image data.
