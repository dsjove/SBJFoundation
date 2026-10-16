import Foundation
import UniformTypeIdentifiers
import SBJLocalization

/// Application-level values used while resolving help templates.
///
/// Defaults preserve the historical Software by Jove help contract while
/// allowing an application to override every value when needed.
public struct SBJHelpConfiguration {
    public var aboutAsset: SBJBundledContentReference?
    public var styleSheetAsset: SBJBundledContentReference?
    public var autoPresentAbout: Bool
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
        substitutions: [String: String] = [:],
        semanticImages: [String: SBJSymbol] = SBJSymbology.all,
        embeddedAssets: [String: SBJBundledContentReference] = [
            "SBJ_STRUCTURE_EDITOR_CORE_HELP": .structureEditorCore,
            "SBJ_STRUCTURE_EDITOR_SEARCH_HELP": .structureEditorSearch,
        ]
    ) {
        self.aboutAsset = aboutAsset
        self.styleSheetAsset = styleSheetAsset
        self.autoPresentAbout = autoPresentAbout
        self.substitutions = substitutions
        self.semanticImages = semanticImages
        self.embeddedAssets = embeddedAssets
    }

    public static var standard: Self { .init() }

}

