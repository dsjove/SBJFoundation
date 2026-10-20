import SBJUIVocabulary
import SBJUnits
#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

/// The textual label portion of an editor row.
///
/// Change/empty state is deliberately not rendered here. Those are row state,
/// not part of the field name, and are owned by `SBJEditorRow` so they occupy
/// stable semantic lanes.
struct SBJEditorFieldName: View {
    @Environment(SBJEditorPresentationModel.self) private var sbjFormattingModel: SBJEditorPresentationModel?
    private var sbjFormatting: SBJEditorFormattingOptions { sbjFormattingModel?.formattingOptions ?? .init() }
    let text: String
    let isUnknown: Bool

    var body: some View {
        Group {
            if isUnknown {
                Text(text)
                    .fontWeight(.semibold)
                    .italic()
            } else {
                Text(text)
            }
        }
        .frame(minHeight: sbjFormatting.firstLineMinimumHeight, alignment: .center)
        .allowsHitTesting(false)
    }
}
#endif
