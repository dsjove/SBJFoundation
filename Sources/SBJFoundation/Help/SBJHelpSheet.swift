#if !os(watchOS)
import SwiftUI

/// Shared help presentation chrome for every help representation.
///
/// About is intentionally part of the help system and uses the same loading,
/// token expansion, presenter selection, and sheet presentation as any other
/// help resource.
@MainActor
public struct SBJHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let asset: SBJAssetReference
    public let substitutions: [String: String]
    public let configuration: SBJHelpConfiguration
    public let showAbout: Bool
    public let presenter: SBJAnyHelpContentPresenter?

    @State private var showAboutSheet = false

    public init(
        asset: SBJAssetReference,
        substitutions: [String: String] = [:],
        configuration: SBJHelpConfiguration = .standard,
        showAbout: Bool = true,
        presenter: SBJAnyHelpContentPresenter? = nil
    ) {
        self.asset = asset
        self.substitutions = substitutions
        self.configuration = configuration
        self.showAbout = showAbout
        self.presenter = presenter
    }

    private var resolvedSource: String? {
        SBJHelpTemplateRenderer(configuration: configuration)
            .renderedSource(for: asset, substitutions: substitutions)
    }

    private var selectedPresenter: SBJAnyHelpContentPresenter? {
        guard let contentType = asset.contentType else { return nil }
        if let presenter, contentType.conforms(to: presenter.contentType) { return presenter }
        return SBJHelpPresenters.builtIn(for: contentType)
    }

    private var availableAboutAsset: SBJAssetReference? {
        guard showAbout, let about = configuration.aboutAsset, about.exists else { return nil }
        return about
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle(asset.displayName)
                .sbjInlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { dismiss() } label: {
                            Label("Dismiss", image: SBJSemanticImageReference.dismiss)
                        }
                    }
                    if availableAboutAsset != nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showAboutSheet = true } label: {
                                Label("About", image: SBJSemanticImageReference.about)
                            }
                        }
                    }
                }
        }
        .onAppear {
            if
                configuration.autoPresentAbout,
                let about = availableAboutAsset,
                !SBJHelpPresentationHistory.hasPresented(about)
            {
                SBJHelpPresentationHistory.markPresented(about)
                showAboutSheet = true
            }
        }
        .sheet(isPresented: $showAboutSheet) {
            if let about = availableAboutAsset {
                SBJHelpSheet(
                    asset: about,
                    substitutions: substitutions,
                    configuration: configuration,
                    showAbout: false
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let source = resolvedSource, let presenter = selectedPresenter {
            presenter.makeView(source: source)
        } else if resolvedSource == nil {
            ContentUnavailableView {
                Label("Help Unavailable", image: SBJSemanticImageReference.helpUnavailable)
            } description: {
                Text("Help is unavailable for this part of the app.")
            }
        } else {
            ContentUnavailableView {
                Label("Unsupported Help Format", image: SBJSemanticImageReference.unsupportedHelp)
            } description: {
                Text("This help format cannot be displayed.")
            }
        }
    }
}
#endif


#if !os(watchOS)
public extension View {
    @ViewBuilder
    func sbjInlineNavigationTitle() -> some View {
#if os(tvOS)
        self
#else
        self.navigationBarTitleDisplayMode(.inline)
#endif
    }
}
#endif
