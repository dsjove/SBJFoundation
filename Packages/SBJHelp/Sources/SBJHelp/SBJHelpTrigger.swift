#if !os(watchOS)
import SwiftUI
import SBJFileResources
import Foundation

/// Shared presentation behavior for help entry controls.
///
/// This owns sheet presentation and the historical first-use automatic help
/// behavior. The caller supplies only the visible control, which lets new code
/// use SwiftUI's `HelpLink` while legacy adapters preserve their old labels.
enum SBJHelpPresentationHistory {
    private static func key(for asset: SBJBundledContentReference) -> String {
        asset.fullName
    }

    static func hasPresented(_ asset: SBJBundledContentReference) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: asset))
    }

    static func markPresented(_ asset: SBJBundledContentReference) {
        DefaultsStorage<Bool>(wrappedValue: false, key(for: asset)).wrappedValue = true
    }
}

@MainActor
public struct SBJHelpTrigger<Label: View>: View {
    public let asset: SBJBundledContentReference
    public let auto: Bool
    public let substitutions: [String: String]
    public let configuration: SBJHelpConfiguration
    public let showAbout: Bool
    public let presenter: SBJAnyHelpContentPresenter?

    private let label: (@escaping () -> Void) -> Label
    @State private var showHelp: Bool

    public init(
        asset: SBJBundledContentReference,
        auto: Bool = false,
        substitutions: [String: String] = [:],
        configuration: SBJHelpConfiguration = .standard,
        showAbout: Bool = true,
        presenter: SBJAnyHelpContentPresenter? = nil,
        initialIsPresented: Bool = false,
        @ViewBuilder label: @escaping (@escaping () -> Void) -> Label
    ) {
        self.asset = asset
        self.auto = auto
        self.substitutions = substitutions
        self.configuration = configuration
        self.showAbout = showAbout
        self.presenter = presenter
        self.label = label
        _showHelp = State(initialValue: initialIsPresented)
    }

    public var body: some View {
        if asset.exists {
            helpControl
                .sheet(isPresented: $showHelp) {
                    SBJHelpSheet(
                        asset: asset,
                        substitutions: substitutions,
                        configuration: configuration,
                        showAbout: showAbout,
                        presenter: presenter
                    )
                }
                .onAppear {
                    if auto && !SBJHelpPresentationHistory.hasPresented(asset) {
                        SBJHelpPresentationHistory.markPresented(asset)
                        showHelp = true
                    }
                }
        }
    }

    @ViewBuilder
    private var helpControl: some View {
        if auto {
            ZStack {
                label { showHelp = true }

                // Automatic help must have a rendered participant of its own.
                // A caller may intentionally supply EmptyView when it wants only
                // first-use presentation; attaching onAppear to EmptyView is not
                // a reliable lifecycle signal.
                Color.clear
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        } else {
            // Keep non-automatic controls structurally transparent. This matters
            // inside system toolbars: an extra container can prevent SwiftUI from
            // freely collapsing or relocating the underlying Button/Menu item.
            label { showHelp = true }
        }
    }
}
#endif
