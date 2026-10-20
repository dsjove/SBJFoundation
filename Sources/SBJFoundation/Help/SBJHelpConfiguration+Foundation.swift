import SBJUIVocabulary
import Foundation
import SBJHelp
import SBJFileResources

#if canImport(UIKit)
import UIKit
#endif

public extension SBJHelpConfiguration {
    /// Application-specific substitution values and framework-owned embedded Help pages.
    static var foundation: Self {
        var config = Self.standard
        config.applicationSubstitutions = [
            "DISPLAY_NAME": AppInfo.displayName,
            "VERSION": AppInfo.fullVersion,
            "COMPANY_NAME": AppInfo.companyName,
            "EMAIL": AppInfo.supportEmail,
            "URL": AppInfo.supportURL,
            "PRIVACY_URL": AppInfo.privacyPolicyURL,
        ]
        #if canImport(UIKit)
        config.applicationSubstitutions["ICON"] = AppInfo.icon?.pngData()?.base64EncodedString() ?? ""
        #endif
        config.embeddedAssets = [
            "SBJ_STRUCTURE_EDITOR_CORE_HELP": .structureEditorCore,
            "SBJ_STRUCTURE_EDITOR_SEARCH_HELP": .structureEditorSearch,
        ]
        return config
    }
}
