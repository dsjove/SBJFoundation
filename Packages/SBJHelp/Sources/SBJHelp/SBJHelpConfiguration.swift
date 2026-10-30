import Foundation
import UniformTypeIdentifiers
import SBJFileResources
import SBJLocalization

/// Application-level values used while resolving help templates.
///
/// Defaults preserve the historical Software by Jove help contract while
/// allowing an application to override every value when needed.
public struct SBJHelpConfiguration {
    public var aboutAsset: SBJBundledContentReference?
    public var styleSheetAsset: SBJBundledContentReference?
    public var autoPresentAbout: Bool
    public var applicationSubstitutions: [String: String]
    public var substitutions: [String: String]
    /// Semantic images available to HTML help as `UI_name\` tokens.
    /// Keeping these names semantic lets help use the same image vocabulary as
    /// the application UI instead of repeating SF Symbol names in documentation.
    public var semanticImages: [String: SBJSymbol]
    /// Optional image used by the standard `ICON` token. Apps can provide a
    /// dedicated help-sized copy of their app icon as an ordinary image asset.
    public var embeddedAssets: [String: SBJBundledContentReference]

    public init(
        aboutAsset: SBJBundledContentReference? = .help("About"),
        styleSheetAsset: SBJBundledContentReference? = .help("Style Sheet"),
        autoPresentAbout: Bool = true,
        applicationSubstitutions: [String: String] = [:],
        substitutions: [String: String] = [:],
        semanticImages: [String: SBJSymbol] = SBJHelpConfiguration.standardSemanticImages,
        embeddedAssets: [String: SBJBundledContentReference] = [:]
    ) {
        self.aboutAsset = aboutAsset
        self.styleSheetAsset = styleSheetAsset
        self.autoPresentAbout = autoPresentAbout
        self.applicationSubstitutions = applicationSubstitutions
        self.substitutions = substitutions
        self.semanticImages = semanticImages
        self.embeddedAssets = embeddedAssets

         self.applicationSubstitutions = [
            "DISPLAY_NAME": AppInfo.displayName,
            "VERSION": AppInfo.fullVersion,
            "COMPANY_NAME": AppInfo.companyName,
            "EMAIL": AppInfo.supportEmail,
            "URL": AppInfo.supportURL,
            "PRIVACY_URL": AppInfo.privacyPolicyURL,
        ].merging(applicationSubstitutions) { _, supplied in supplied }
        #if canImport(UIKit) && !os(watchOS)
		self.applicationSubstitutions["ICON"] = AppInfo.icon?.resized(toFit: .init(width: 256, height: 256)).pngData()?.base64EncodedString() ?? ""
        #endif
    }

    /// Merge a domain's semantic symbols into this help configuration.
    /// Later sets override duplicate keys; standard UI symbols are included by default.
    public mutating func addSymbolSet<S: SBJSymbolSet>(_ type: S.Type) {
        semanticImages.merge(type.all) { _, new in new }
    }

    /// Common UI symbols and help-owned symbols, composed in one place.
    public static var standardSemanticImages: [String: SBJSymbol] {
        var images = SBJSymbology.all
        images.merge(SBJHelpSymbology.all) { _, help in help }
        return images
    }

    public static var standard: Self { .init() }
}
