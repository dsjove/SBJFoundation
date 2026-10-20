import SwiftUI
import SBJFileResources
import SBJLocalization

/// Presentation of a URL action, following SwiftUI `Label` conventions.
public enum SBJURLButtonStyle: Sendable {
    case iconOnly
    case titleOnly
    case titleAndIcon
}

/// Opens a URL using the application's platform URL-opening behavior in
/// `SBJFileResources`, not SwiftUI's `openURL` environment.
///
/// The title defaults to the URL host (or the full URL if no host is available).
/// An unavailable URL retains its label but cannot be activated.
@MainActor
public struct SBJURLButton: View {
    public let url: URL?
    public let title: String?
    public let style: SBJURLButtonStyle
    private let explicitAccessibilityLabel: String?

    public init(
        url: URL?,
        title: String? = nil,
        style: SBJURLButtonStyle = .iconOnly,
        accessibilityLabel: String? = nil
    ) {
        self.url = url
        self.title = title
        self.style = style
        self.explicitAccessibilityLabel = accessibilityLabel
    }

    private var isOpenable: Bool { url?.isValidURL ?? false }

    private var labelText: String {
        if let title, !title.isEmpty { return title }
        guard let url else { return "" }
        return url.host ?? url.absoluteString
    }

    private var symbol: SBJSymbol {
        (url?.absoluteString.isEmpty ?? true) ? SBJSymbology.unavailableLink : SBJSymbology.link
    }

    private var accessibleText: String {
        explicitAccessibilityLabel ?? (labelText.isEmpty ? "Open link" : "Open \(labelText)")
    }

    public var body: some View {
        Group {
            switch style {
            case .iconOnly:
                SBJSymbolButton(symbol, accessibilityLabel: accessibleText) {
                    URL.open(url)
                }
                .imageScale(.large)
                .foregroundStyle(isOpenable ? SBJUIAppearance.interactiveColor : SBJUIAppearance.inactiveControlColor)
                .disabled(!isOpenable)

            case .titleOnly, .titleAndIcon:
                if !labelText.isEmpty {
                    Button {
                        URL.open(url)
                    } label: {
                        if style == .titleAndIcon {
                            Label {
                                Text(labelText)
                            } icon: {
                                Image(symbol: symbol)
                            }
                        } else {
                            Text(labelText)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isOpenable ? SBJUIAppearance.interactiveColor : SBJUIAppearance.inactiveControlColor)
                    .disabled(!isOpenable)
                    .accessibilityLabel(accessibleText)
                }
            }
        }
    }
}
