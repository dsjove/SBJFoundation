import Foundation
import UniformTypeIdentifiers

public extension SBJBundledContentReference {
    /// HTML help stored in the standard `help` resource directory.
    static func help(
        _ displayName: String,
        resourceName: String? = nil,
        bundle: Bundle = .main
    ) -> SBJBundledContentReference {
        SBJBundledContentReference(
            displayName: displayName,
            resourceName: resourceName,
            subdirectory: "help",
            bundle: bundle,
            contentType: .html
        )
    }
}
