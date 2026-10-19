import SwiftUI
import UniformTypeIdentifiers

/// A content-type-specific help presenter.
///
/// The sheet/chrome is independent of this protocol. New help representations
/// can provide a presenter without changing the referenced resource or the surrounding
/// help UI.
@MainActor
public protocol SBJHelpContentPresenter {
    var contentType: UTType { get }
    func makeView(source: String) -> AnyView
}

/// Type erasure for injecting an application- or package-defined presenter.
public struct SBJAnyHelpContentPresenter: SBJHelpContentPresenter {
    public let contentType: UTType
    private let make: @MainActor (String) -> AnyView

    public init<P: SBJHelpContentPresenter>(_ presenter: P) {
        contentType = presenter.contentType
        make = presenter.makeView
    }

    public init(
        contentType: UTType,
        makeView: @escaping @MainActor (String) -> AnyView
    ) {
        self.contentType = contentType
        self.make = makeView
    }

    public func makeView(source: String) -> AnyView {
        make(source)
    }
}

@MainActor
public enum SBJHelpPresenters {
    public static func builtIn(for contentType: UTType) -> SBJAnyHelpContentPresenter? {
        #if canImport(UIKit) && canImport(WebKit)
        if contentType.conforms(to: .html) {
            return SBJAnyHelpContentPresenter(SBJHTMLHelpPresenter())
        }
        #endif
        #if targetEnvironment(macCatalyst)
        if #available(macCatalyst 27.0, *), contentType.conforms(to: .markdown) {
            return SBJAnyHelpContentPresenter(SBJMarkdownHelpPresenter())
        }
        #elseif os(iOS)
        if #available(iOS 27.0, *), contentType.conforms(to: .markdown) {
            return SBJAnyHelpContentPresenter(SBJMarkdownHelpPresenter())
        }
        #endif
        return nil
    }
}
