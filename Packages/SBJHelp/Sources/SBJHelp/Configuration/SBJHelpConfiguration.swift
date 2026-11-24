import Foundation
import UniformTypeIdentifiers
import SBJLocalization
import SBJFileResources

/// Application-level values used while resolving help templates.
///
/// The defaults provide application metadata and shared semantic vocabularies.
/// Caller values override defaults without requiring a custom help presenter.
public struct SBJHelpConfiguration {
    public var aboutAsset: SBJBundledContentReference?
    /// Optional additional CSS for an exceptional host-specific requirement.
    /// The shared SBJHelp stylesheet is always applied first.
    public var styleSheetAsset: SBJBundledContentReference?
    public var autoPresentAbout: Bool
    public var applicationSubstitutions: [String: String]
    public var substitutions: [String: String]
    /// Semantic images available to HTML help as `UI_name\` tokens.
    /// Keeping these names semantic lets help use the same image vocabulary as
    /// the application UI instead of repeating SF Symbol names in documentation.
    public var semanticImages: [String: SBJSymbol]
    /// Stable IDs resolved into a complete symbol/title/details help entry.
    public var nomenclatures: [String: SBJNomenclature]
    /// Optional image used by the standard `ICON` token. Apps can provide a
    /// dedicated help-sized copy of their app icon as an ordinary image asset.
    public var embeddedAssets: [String: SBJBundledContentReference]

    public init(
        aboutAsset: SBJBundledContentReference? = .help("About"),
        styleSheetAsset: SBJBundledContentReference? = nil,
        autoPresentAbout: Bool = true,
        applicationSubstitutions: [String: String] = [:],
        substitutions: [String: String] = [:],
        semanticImages: [String: SBJSymbol] = SBJHelpConfiguration.standardSemanticImages,
        nomenclatures: [String: SBJNomenclature] = SBJCommonNomenclature.all.merging(SBJHelpNomenclature.all) { _, help in help },
        embeddedAssets: [String: SBJBundledContentReference] = [:]
    ) {
        self.aboutAsset = aboutAsset
        self.styleSheetAsset = styleSheetAsset
        self.autoPresentAbout = autoPresentAbout
        self.applicationSubstitutions = applicationSubstitutions
        self.substitutions = substitutions
        self.semanticImages = semanticImages
        self.nomenclatures = nomenclatures
        self.embeddedAssets = embeddedAssets

        self.applicationSubstitutions = [
            "DISPLAY_NAME": AppInfo.displayName,
            "VERSION": AppInfo.fullVersion,
            "COMPANY_NAME": AppInfo.companyName,
            "EMAIL": AppInfo.supportEmail,
            "URL": AppInfo.supportURL,
            "PRIVACY_URL": AppInfo.privacyPolicyURL,
        ].merging(applicationSubstitutions) { _, supplied in supplied }
        #if (canImport(UIKit) || canImport(AppKit)) && !os(watchOS)
        if self.applicationSubstitutions["ICON"] == nil {
            self.applicationSubstitutions["ICON"] = SBJHelpImageEncoding.pngData(for: AppInfo.icon?.resized(toFit: .init(width: 256, height: 256)))?.base64EncodedString() ?? ""
        }
        #endif
    }

    /// Merge a domain's semantic symbols into this help configuration.
    /// Later sets override duplicate keys; standard UI symbols are included by default.
    public mutating func addSymbolSet<S: SBJSymbolSet>(_ type: S.Type) {
        semanticImages.merge(type.all) { _, new in new }
    }

    /// Register shared, owning-package definitions without duplicating their strings.
    public mutating func addNomenclatureSet<N: SBJNomenclatureSet>(_ type: N.Type) {
        nomenclatures.merge(type.all) { _, new in new }
    }

    /// Common UI symbols and help-owned symbols, composed in one place.
    public static var standardSemanticImages: [String: SBJSymbol] {
        var images = SBJSymbology.all
        images.merge(SBJHelpSymbology.all) { _, help in help }
        return images
    }

    public static var standard: Self { .init() }
}
