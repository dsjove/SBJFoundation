import SwiftUI
import SBJFileResources
import SBJLocalization

/// Shared file-navigation action nomenclature; the filename is runtime context.
public enum SBJFileNavigationNomenclature: SBJNomenclatureSet {
    public static let all: [String: SBJNomenclature] = [
        "showInFinder": .init(
            title: "Show in Finder",
            details: "Reveal the selected file in Finder.",
            symbol: .system("arrow.up.right")),
    ]
}

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
                Image(symbol: SBJFileNavigationNomenclature.showInFinder.symbol!)
                    .font(.caption2)
                    .frame(minWidth: 24, minHeight: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibility(label: "\(SBJFileNavigationNomenclature.showInFinder.title): \(url.lastPathComponent)",
                           hint: SBJFileNavigationNomenclature.showInFinder.summary)
            .help(SBJFileNavigationNomenclature.showInFinder.title)
        }
    }
}
