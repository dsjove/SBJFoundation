import Foundation
import SwiftUI
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(UIKit)
import UIKit
#endif

public extension SBJSymbol {
    /// Renders the symbol without involving general image or document loading.
    var image: Image {
        switch self {
        case .system(let name):
            return Image(systemName: name)
        case .asset(let name, let bundle):
            return Image(name, bundle: bundle).renderingMode(.template)
        case .bundleImage:
            #if canImport(ImageIO)
            if let url = bundledImageURL,
               let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                return Image(decorative: cgImage, scale: 1)
            }
            #endif
            return Image("")
        }
    }

    /// Location of a bundled image file, if this symbol uses one.
    var bundledImageURL: URL? {
        guard case let .bundleImage(name, ext, directory, bundle) = self else { return nil }
        return (bundle ?? .main).url(forResource: name, withExtension: ext, subdirectory: directory)
    }
}

public extension Image {
    init(symbol: SBJSymbol) { self = symbol.image }
}

#if canImport(UIKit)
public extension SBJSymbol {
    var uiImage: UIImage? {
        switch self {
        case .system(let name):
            return UIImage(systemName: name)
        case .asset(let name, let bundle):
            #if os(watchOS)
            return UIImage(named: name)
            #else
            return UIImage(named: name, in: bundle, compatibleWith: nil)
            #endif
        case .bundleImage:
            guard let url = bundledImageURL else { return nil }
            return UIImage(contentsOfFile: url.path)
        }
    }
}
#endif

public extension Label where Title == Text, Icon == Image {
    init(_ title: LocalizedStringKey, symbol: SBJSymbol) {
        self = Label { Text(title) } icon: { Image(symbol: symbol) }
    }
    init(_ title: String, symbol: SBJSymbol) {
        self = Label { Text(title) } icon: { Image(symbol: symbol) }
    }
}

/// A semantic title-and-symbol label without a prescribed presentation style.
/// When inside a control, apply interaction accessibility to that control, not here.
/// When standalone, the title is normally the spoken label; associate separately
/// presented labels with their controls to avoid redundant VoiceOver stops.
public extension Label where Title == Text, Icon == Image {
    init(_ definition: SBJLabeledSymbol) {
        self = Label {
            Text(definition.title)
        } icon: {
            Image(symbol: definition.symbol)
        }
    }

    /// Creates an icon-only label with no title. Prefer `Label(title, symbol:)`
    /// for meaningful content, or `Image(symbol:)` for decorative imagery.
    @available(*, deprecated, message: "Use Label(title, symbol:) or Image(symbol:) as appropriate")
    init(_ symbol: SBJSymbol) {
        self = Label { Text("") } icon: { Image(symbol: symbol) }
    }
}
