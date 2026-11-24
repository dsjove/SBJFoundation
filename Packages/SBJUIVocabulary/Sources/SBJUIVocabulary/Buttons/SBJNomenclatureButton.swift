#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// Reusable information action and help presentation for annotated properties.
@MainActor
public struct SBJNomenclatureButton: View {
    private let propertyName: String
    private let info: SBJNomenclature?
    private let additionalInfo: (() -> (title: String, info: SBJNomenclature)?)?
    @State private var isPresented = false

    public init(propertyName: String, info: SBJNomenclature?,
                additionalInfo: (() -> (title: String, info: SBJNomenclature)?)? = nil) {
        self.propertyName = propertyName
        self.info = info
        self.additionalInfo = additionalInfo
    }

    private var title: String { info?.nonEmptyTitle ?? propertyName }

    public var body: some View {
        SBJSymbolButton(
            SBJSymbology.information,
            accessibilityLabel: info?.accessibilityLabel ?? "Information about \(title)",
            accessibilityHint: info?.accessibilityHint ?? info?.summary ?? additionalInfo?()?.info.summary
        ) { isPresented = true }
#if os(iOS)
        .popover(isPresented: $isPresented) {
            SBJNomenclatureSheet(title: title, info: info, additionalInfo: additionalInfo?(), showsDoneButton: false) {
                isPresented = false
            }
            .presentationCompactAdaptation(.popover)
        }
#else
        .sheet(isPresented: $isPresented) {
            SBJNomenclatureSheet(title: title, info: info, additionalInfo: additionalInfo?(), showsDoneButton: true) {
                isPresented = false
            }
        }
#endif
    }
}

@MainActor
private struct SBJNomenclatureSheet: View {
    let title: String
    let info: SBJNomenclature?
    let additionalInfo: (title: String, info: SBJNomenclature)?
    let showsDoneButton: Bool
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Image(symbol: info?.symbol ?? SBJSymbology.information)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title).font(.title2.weight(.semibold))
                if showsDoneButton {
                    Spacer(minLength: 12)
                    Button("Done", action: dismiss)
                }
            }
            if let info { details(info) }
            if let additionalInfo {
                if info != nil { Divider().padding(.vertical, 2) }
                Text(additionalInfo.title).font(.headline)
                details(additionalInfo.info)
            }
        }
        .padding(14)
        .frame(idealWidth: 440, maxWidth: 520, idealHeight: 320, maxHeight: 520)
    }

    @ViewBuilder
    private func details(_ info: SBJNomenclature) -> some View {
        if let summary = info.summary {
            Text(summary).font(.subheadline.weight(.semibold))
        }
        if let text = info.details {
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
