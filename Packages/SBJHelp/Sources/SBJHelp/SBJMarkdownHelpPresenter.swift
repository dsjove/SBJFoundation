import SwiftUI
import UniformTypeIdentifiers

/// Native SwiftUI presenter for Markdown help assets.
@available(iOS 27.0, *)
@available(macCatalyst 27.0, *)
@available(tvOS 27.0, *)
public struct SBJMarkdownHelpPresenter: SBJHelpContentPresenter {
    public let contentType: UTType = UTType(filenameExtension: "md") ?? .plainText

    public init() {}

    @MainActor
    public func makeView(source: String) -> AnyView {
        let attributed: AttributedString
        do {
            attributed = try AttributedString(
                markdown: source,
                options: .init(interpretedSyntax: .full)
            )
        } catch {
            attributed = AttributedString(source)
        }

        return AnyView(
            ScrollView {
                Text(attributed)
                    .sbjSelectableHelpText()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        )
    }
}


private extension View {
    @ViewBuilder
    func sbjSelectableHelpText() -> some View {
#if os(tvOS) || os(watchOS)
        self
#else
        self.textSelection(.enabled)
#endif
    }
}
