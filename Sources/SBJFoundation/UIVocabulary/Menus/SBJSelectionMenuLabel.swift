import SwiftUI

/// Shared selection-menu label presentation.
///
/// When `options` are supplied, the text column reserves the width of its
/// widest option so choosing another value does not move the trailing chevrons.
@MainActor
public struct SBJSelectionMenuLabel: View {
    public let text: String
    public let options: [String]

    public init(text: String, options: [String] = []) {
        self.text = text
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .leading) {
                ForEach(Array(([text] + options).enumerated()), id: \.offset) { _, option in
                    Text(option)
                        .lineLimit(1)
                        .hidden()
                }
                Text(text)
                    .lineLimit(1)
            }
            Image(.system("chevron.up.chevron.down"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
