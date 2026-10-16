import SwiftUI

/// Shared read-only URL presentation using the same URL-opening behavior as
/// `URLButton` rather than SwiftUI's separate `Link`/`openURL` path.
public struct URLText: View {
    public let name: String
    public let url: URL?

    public init(name: String = "", url: URL?) {
        self.name = name
        self.url = url
    }

    @MainActor
    private var isOpenable: Bool {
        url?.isValidURL ?? false
    }

    public var body: some View {
        if let url {
            let simpleName = name.isEmpty ? (url.host ?? url.absoluteString) : name
            if isOpenable {
                Button(simpleName) { url.open() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
            } else {
                Text(simpleName)
            }
        } else if !name.isEmpty {
            Text(name)
        }
    }
}
