#if !os(tvOS) && !os(watchOS)
import SwiftUI
import SBJDataDefinition

/// Reusable information action and help presentation for annotated properties.
@MainActor
public struct SBJPropertyInfoButton: View {
    private let propertyName: String
    private let info: SBJPropertyInfo?
    private let additionalInfo: (() -> (title: String, info: SBJPropertyInfo)?)?
    @State private var isPresented = false

    public init(propertyName: String, info: SBJPropertyInfo?,
                additionalInfo: (() -> (title: String, info: SBJPropertyInfo)?)? = nil) {
        self.propertyName = propertyName
        self.info = info
        self.additionalInfo = additionalInfo
    }

    private var title: String { info?.title ?? propertyName }

    public var body: some View {
        SBJSymbolButton(
            SBJSymbology.information,
            accessibilityLabel: info?.accessibilityLabel ?? "Information about \(title)",
            accessibilityHint: info?.accessibilityHint ?? info?.summary ?? additionalInfo?()?.info.summary
        ) { isPresented = true }
#if os(iOS)
        .popover(isPresented: $isPresented) {
            SBJPropertyInfoSheet(title: title, info: info, additionalInfo: additionalInfo?(), showsDoneButton: false) {
                isPresented = false
            }
            .presentationCompactAdaptation(.popover)
        }
#else
        .sheet(isPresented: $isPresented) {
            SBJPropertyInfoSheet(title: title, info: info, additionalInfo: additionalInfo?(), showsDoneButton: true) {
                isPresented = false
            }
        }
#endif
    }
}

@MainActor
private struct SBJPropertyInfoSheet: View {
    let title: String
    let info: SBJPropertyInfo?
    let additionalInfo: (title: String, info: SBJPropertyInfo)?
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
    private func details(_ info: SBJPropertyInfo) -> some View {
        if let summary = info.summary {
            Text(summary).font(.subheadline.weight(.semibold))
        }
        if let text = info.details {
            ScrollView {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
#endif
