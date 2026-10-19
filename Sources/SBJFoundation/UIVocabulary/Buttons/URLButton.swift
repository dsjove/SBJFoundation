import SBJFileResources
import SwiftUI
import SBJDataDefinition
import SBJLocalization

/// Shared URL action for reusable interfaces.
/// Opening is routed through the framework's platform `URL.open()` abstraction.
public struct URLButton: View {
    public let url: URL?
    private let accessibilityLabel: String

    public init(url: URL?, accessibilityLabel: String = "Open link") {
        self.url = url
        self.accessibilityLabel = accessibilityLabel
    }

    @MainActor
    private var isOpenable: Bool {
        url?.isValidURL ?? false
    }

    public var body: some View {
        SBJImageButton(
            (url?.absoluteString.isEmpty ?? true) ? SBJSymbology.unavailableLink : SBJSymbology.link,
            accessibilityLabel: accessibilityLabel
        ) {
            URL.open(url)
        }
        .imageScale(.large)
        .foregroundStyle(isOpenable ? SBJUIAppearance.interactiveColor : SBJUIAppearance.inactiveControlColor)
        .disabled(!isOpenable)
    }
}
