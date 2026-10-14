#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Understated explanatory content for a disclosure that is open but has no
/// visible editor rows beneath its header.
struct SBJEditorEmptyDisclosureContent: View {
    @Environment(SBJEditorPresentationModel.self) private var sbjFormattingModel: SBJEditorPresentationModel?
    private var sbjFormatting: SBJEditorFormattingOptions { sbjFormattingModel?.formattingOptions ?? .init() }
    let message: String

    var body: some View {
        Text(message)
            .italic()
            .foregroundStyle(.secondary)
            .frame(
                maxWidth: .infinity,
                minHeight: sbjFormatting.firstLineMinimumHeight,
                alignment: .leading
            )
    }
}
#endif
