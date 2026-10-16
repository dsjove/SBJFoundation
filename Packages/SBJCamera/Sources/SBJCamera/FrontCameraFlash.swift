import SwiftUI
import Observation

/// Coordinates a simulated front-camera flash.
///
/// Attach the coordinator to the camera view hierarchy with
/// `View.frontCameraFlash(_:)`, then call `perform(_:)` for captures that
/// should use the display as a flash. The coordinator owns the timing so
/// clients do not need to duplicate delays around the shutter action.
@MainActor
@Observable
public final class FrontCameraFlash {
    public private(set) var isActive = false

    private let exposureDelay: Duration
    private let shutterHoldDuration: Duration

    /// Creates a simulated front-camera flash coordinator.
    ///
    /// - Parameters:
    ///   - exposureDelay: Time to illuminate the display before invoking the
    ///     shutter, allowing the camera exposure to react to the added light.
    ///   - shutterHoldDuration: Time to keep the display illuminated after the
    ///     shutter request so the flash remains present across capture.
    public init(
        exposureDelay: Duration = .milliseconds(120),
        shutterHoldDuration: Duration = .milliseconds(350)
    ) {
        self.exposureDelay = exposureDelay
        self.shutterHoldDuration = shutterHoldDuration
    }

    /// Illuminates the display, invokes the shutter action, then restores the
    /// display after the capture interval.
    public func perform(_ capture: @escaping @MainActor () -> Void) async {
        isActive = true

        // Allow SwiftUI to render the white surface before waiting for the
        // camera exposure to react to it.
        await Task.yield()
        try? await Task.sleep(for: exposureDelay)

        guard !Task.isCancelled else {
            isActive = false
            return
        }

        capture()
        try? await Task.sleep(for: shutterHoldDuration)
        isActive = false
    }

    /// Immediately ends an in-progress simulated flash.
    public func cancel() {
        isActive = false
    }
}

#if os(iOS)
import UIKit

/// Adds the presentation layer for a reusable simulated front-camera flash.
///
/// While the coordinator is active, this modifier draws a full-screen white
/// surface, raises the brightness of the screen hosting this view to maximum,
/// and restores the previous brightness afterward.
public extension View {
    func frontCameraFlash(_ flash: FrontCameraFlash) -> some View {
        modifier(FrontCameraFlashModifier(flash: flash))
    }
}

@MainActor
private struct FrontCameraFlashModifier: ViewModifier {
    let flash: FrontCameraFlash

    func body(content: Content) -> some View {
        content
            .background {
                FrontCameraFlashScreenController(isActive: flash.isActive)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            }
            .overlay {
                if flash.isActive {
                    Color.white
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
    }
}

@MainActor
private struct FrontCameraFlashScreenController: UIViewRepresentable {
    let isActive: Bool

    func makeUIView(context: Context) -> FlashHostView {
        let view = FlashHostView()
        view.setActive(isActive)
        return view
    }

    func updateUIView(_ uiView: FlashHostView, context: Context) {
        uiView.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: FlashHostView, coordinator: ()) {
        uiView.restoreBrightness()
    }
}

@MainActor
private final class FlashHostView: UIView {
    private var isActive = false
    private weak var brightenedScreen: UIScreen?
    private var previousBrightness: CGFloat?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyState()
    }

    func setActive(_ isActive: Bool) {
        self.isActive = isActive
        applyState()
    }

    func restoreBrightness() {
        guard let screen = brightenedScreen, let previousBrightness else { return }
        screen.brightness = previousBrightness
        brightenedScreen = nil
        self.previousBrightness = nil
    }

    private func applyState() {
        if isActive {
            guard let screen = window?.screen else { return }
            if brightenedScreen !== screen {
                restoreBrightness()
                brightenedScreen = screen
                previousBrightness = screen.brightness
            }
            screen.brightness = 1.0
        } else {
            restoreBrightness()
        }
    }
}

#else

public extension View {
    func frontCameraFlash(_ flash: FrontCameraFlash) -> some View {
        self
    }
}

#endif
