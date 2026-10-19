import Foundation
import SBJDataDefinition
import SBJFileResources
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

    static var editTags: SBJBundledContentReference {
        .help("Edit Tags", bundle: .module)
    }

    static var attachmentsHelp: SBJBundledContentReference {
        .help("Attachments", bundle: .module)
    }

    static var unitConversionHelp: SBJBundledContentReference {
        .help("Unit Conversion", bundle: .module)
    }

    static var structureEditorCore: SBJBundledContentReference {
        .help("SBJ Structure Editor Core", bundle: .module)
    }

    static var structureEditorSearch: SBJBundledContentReference {
        .help("SBJ Structure Editor Search", bundle: .module)
    }

    static var imageEdit: SBJBundledContentReference {
        .help("Image Edit", bundle: .module)
    }

    static var imageView: SBJBundledContentReference {
        .help("Image View", bundle: .module)
    }
}
