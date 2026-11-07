import SwiftUI
import SBJFileResources

/// Delegates platform-specific Finder behavior and scoped access to URL.
public struct ShowInFinder: View {
    let url: URL
    let directory: URL?

    public init(url: URL, directory: URL? = nil) {
        self.url = url
        self.directory = directory
    }

    public var body: some View {
        if URL.hasFinder && url.isFileURL {
            Button {
                url.showInFinder(directory: directory)
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .frame(minWidth: 24, minHeight: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(url.lastPathComponent) in Finder")
            .help("Show in Finder")
        }
    }
}
