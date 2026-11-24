#if !os(watchOS) && !os(tvOS) && (canImport(UIKit) || canImport(AppKit))
import SwiftUI
import SBJLocalization

/// Shares a payload using the same nomenclature as other controls and help.
/// Contextual information is appended to the accessible action label, while
/// the underlying name, symbol and guidance remain centrally defined.
@MainActor
public struct SBJShareButton<Label: View>: View {
    private let presenter: SBJSharePresenter
    private let nomenclature: SBJNomenclature
    private let context: String?
    private let prepare: @MainActor () -> SBJSharePayload
    private let onPresent: (@MainActor () -> Void)?
    private let onDismiss: (@MainActor @Sendable () -> Void)?
    private let label: () -> Label

    public init(
        _ nomenclature: SBJNomenclature,
        context: String? = nil,
        presenter: SBJSharePresenter,
        prepare: @escaping @MainActor () -> SBJSharePayload,
        onPresent: (@MainActor () -> Void)? = nil,
        onDismiss: (@MainActor @Sendable () -> Void)? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.nomenclature = nomenclature
        self.context = context
        self.presenter = presenter
        self.prepare = prepare
        self.onPresent = onPresent
        self.onDismiss = onDismiss
        self.label = label
    }

    public var body: some View {
        let baseLabel = nomenclature.accessibilityLabel ?? nomenclature.title
        let spokenLabel = context.map { "\(baseLabel): \($0)" } ?? baseLabel
        return Button {
            guard !presenter.isPresenting else { return }
            let payload = prepare()
            guard presenter.present(payload, onDismiss: onDismiss) else { return }
            onPresent?()
        } label: {
            label()
        }
        .disabled(presenter.isPresenting)
        .accessibility(label: spokenLabel, hint: nomenclature.accessibilityHint ?? nomenclature.summary)
    }
}

public extension SBJShareButton where Label == SwiftUI.Label<Text, Image> {
    init(
        _ nomenclature: SBJNomenclature = SBJCommonNomenclature.share,
        context: String? = nil,
        presenter: SBJSharePresenter,
        prepare: @escaping @MainActor () -> SBJSharePayload,
        onPresent: (@MainActor () -> Void)? = nil,
        onDismiss: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.init(
            nomenclature,
            context: context,
            presenter: presenter,
            prepare: prepare,
            onPresent: onPresent,
            onDismiss: onDismiss
        ) {
            Label(nomenclature)
        }
    }
}
#endif
