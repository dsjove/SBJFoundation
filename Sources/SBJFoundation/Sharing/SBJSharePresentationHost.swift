#if !os(watchOS) && !os(tvOS) && canImport(UIKit)
import SwiftUI

import SBJDataDefinition
/// Stable owner for UIKit share presentation.
///
/// The host creates one `SBJSharePresenter` and passes it explicitly to its
/// content. Controls that can share receive that presenter as a normal
/// dependency rather than discovering it through the SwiftUI environment.
@MainActor
public struct SBJSharePresentationHost<Content: View>: View {
    @Environment(\.presentationChromeSuppression) private var chromeSuppression

    @State private var presenter = SBJSharePresenter()
    @State private var isSuppressingChrome = false

    private let content: (SBJSharePresenter) -> Content

    public init(
        @ViewBuilder content: @escaping (SBJSharePresenter) -> Content
    ) {
        self.content = content
    }

    public var body: some View {
        @Bindable var bindingPresenter = presenter
        content(presenter)
            .sheet(item: $bindingPresenter.presentation, onDismiss: finishPresentation) { presentation in
                ShareSheet(
                    activityItems: presentation.payload.activityItems,
                    applicationActivities: presentation.payload.applicationActivities
                )
            }
            .onChange(of: presenter.presentation?.id) { _, newID in
                synchronizeChromeSuppression(isPresented: newID != nil)
            }
            .onDisappear {
                // Balance the enclosing presentation scope even if SwiftUI tears
                // down this host without delivering the sheet's onDismiss callback.
                synchronizeChromeSuppression(isPresented: false)
            }
    }

    private func finishPresentation() {
        synchronizeChromeSuppression(isPresented: false)
        presenter.finishPresentation()
    }

    private func synchronizeChromeSuppression(isPresented: Bool) {
        if isPresented {
            guard !isSuppressingChrome else { return }
            isSuppressingChrome = true
            chromeSuppression.begin()
        } else {
            guard isSuppressingChrome else { return }
            isSuppressingChrome = false
            chromeSuppression.end()
        }
    }
}
#endif
