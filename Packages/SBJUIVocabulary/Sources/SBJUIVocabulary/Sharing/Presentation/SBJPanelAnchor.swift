#if os(macOS)
import AppKit

/// Runs a native panel's presentation once the SwiftUI-hosted view has a window.
@MainActor
final class SBJPanelAnchor: NSView {
    var onAttach: ((NSView) -> Void)?
    private var didPresent = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !didPresent, let onAttach else { return }
        didPresent = true
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil else { return }
            onAttach(self)
        }
    }
}
#endif
