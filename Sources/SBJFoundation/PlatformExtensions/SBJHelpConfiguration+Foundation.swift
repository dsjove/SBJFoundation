import Foundation
import SBJFileResources
import SBJHelp
import SBJUIVocabulary

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
        #if canImport(UIKit) && !os(watchOS)
		config.applicationSubstitutions["ICON"] = AppInfo.icon?.resized(toFit: .init(width: 256, height: 256)).pngData()?.base64EncodedString() ?? ""
        #endif
        return config
    }
}
