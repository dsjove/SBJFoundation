import Foundation

public extension Bundle {
    /// Resolves a processed bundle resource while tolerating build systems that flatten
    /// authored source subdirectories into the bundle root.
    ///
    /// SwiftPM `.process` and Xcode resource processing do not guarantee that the source-tree
    /// directory hierarchy survives in the built product. Callers may still provide the
    /// authored subdirectory for bundles that preserve it; this helper falls back to the root.
    func sbjResourceURL(
        name: String,
        extension resourceExtension: String? = nil,
        subdirectory: String? = nil
    ) -> URL? {
        if let url = url(
            forResource: name,
            withExtension: resourceExtension,
            subdirectory: subdirectory
        ) {
            return url
        }

        guard subdirectory != nil else { return nil }
        return url(forResource: name, withExtension: resourceExtension)
    }
}
