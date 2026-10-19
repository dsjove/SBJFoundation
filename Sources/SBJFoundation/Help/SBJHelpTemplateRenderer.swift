import Foundation
import SBJDataDefinition
import SBJFileResources
#if canImport(UIKit)
import UIKit
#endif

/// Resolves application, caller, and embedded-help tokens in a help source.
///
/// Caller substitutions take precedence over configuration and standard
/// substitutions. Named embedded help assets are resolved recursively before
/// ordinary replacement, which lets an application compose its own help from
/// reusable framework help without copying the framework text.
public struct SBJHelpTemplateRenderer {
    public let configuration: SBJHelpConfiguration

    public init(configuration: SBJHelpConfiguration = .standard) {
        self.configuration = configuration
    }

    public func renderedSource(
        for asset: SBJBundledContentReference,
        substitutions: [String: String] = [:]
    ) -> String? {
        renderedSource(
            for: asset,
            substitutions: substitutions,
            embeddedStack: []
        )
    }

    public func standardSubstitutions(for asset: SBJBundledContentReference) -> [String: String] {
        let iconData: String
        #if canImport(UIKit)
        let icon = AppInfo.icon
        iconData = icon?.pngData()?.base64EncodedString() ?? ""
        #else
        iconData = ""
        #endif

        return [
            "TITLE": asset.displayName,
            "DISPLAY_NAME": AppInfo.displayName,
            "VERSION": AppInfo.fullVersion,
            "COMPANY_NAME": AppInfo.companyName,
            "EMAIL": AppInfo.supportEmail,
            "URL": AppInfo.supportURL,
            "PRIVACY_URL": AppInfo.privacyPolicyURL,
            "ICON": iconData,
            "STYLE_SHEET": configuration.styleSheetAsset?.stringValue() ?? "",
        ]
    }

    private func renderedSource(
        for asset: SBJBundledContentReference,
        substitutions: [String: String],
        embeddedStack: Set<String>
    ) -> String? {
        guard let source = asset.stringValue() else { return nil }

        var replacements = standardSubstitutions(for: asset)
        replacements.merge(configuration.substitutions) { _, new in new }

        let nextStack = embeddedStack.union([asset.fullName])
        for (token, embeddedAsset) in configuration.embeddedAssets {
            guard !nextStack.contains(embeddedAsset.fullName) else { continue }
            if let embedded = renderedSource(
                for: embeddedAsset,
                substitutions: [:],
                embeddedStack: nextStack
            ) {
                replacements[token] = embedded
            }
        }

        replacements.merge(substitutions) { _, new in new }

        // Resolve text and embedded documents first. Embedded HTML can itself
        // contain image tokens, so image expansion intentionally runs over the
        // composed result rather than only the parent source.
        var rendered = source.replacingOccurrences(using: replacements)
        if asset.contentType?.conforms(to: .html) == true {
            var imageReplacements = extractHTMLImageSubstitutions(from: rendered)
            imageReplacements.merge(extractSemanticImageSubstitutions(from: rendered)) { _, new in new }
            rendered = rendered.replacingOccurrences(using: imageReplacements)
        }
        return rendered
    }


    private func extractSemanticImageSubstitutions(from html: String) -> [String: String] {
        guard let regex = try? NSRegularExpression(pattern: #"UI_([a-zA-Z0-9._-]+)"#) else {
            return [:]
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var results: [String: String] = [:]
        for match in regex.matches(in: html, range: range) {
            guard
                match.numberOfRanges == 2,
                let nameRange = Range(match.range(at: 1), in: html)
            else { continue }
            let name = String(html[nameRange])
#if !os(watchOS)
            guard
                let reference = configuration.semanticImages[name],
                let encoded = encodeImage(
                    reference.uiImage?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)),
                    alt: name
                )
            else { continue }
            results["UI_" + name + "\\"] = encoded
#endif
        }
        return results
    }

    private func extractHTMLImageSubstitutions(from html: String) -> [String: String] {
        var results: [String: String] = [:]
        let patterns: [(String, Bool, String)] = [
            (#"SF_([a-zA-Z0-9.]+)"#, false, "SF_"),
            (#"AS_([a-zA-Z0-9.\-_]+)"#, true, "AS_"),
        ]

        for (pattern, isAsset, prefix) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            for match in regex.matches(in: html, range: range) {
                guard
                    match.numberOfRanges == 2,
                    let range = Range(match.range(at: 1), in: html)
                else { continue }

                let imageName = String(html[range])
                if let encoded = encodeImage(named: imageName, isAsset: isAsset) {
                    results[prefix + imageName + "\\"] = encoded
                }
            }
        }
        return results
    }

    private func encodeImage(named imageName: String, isAsset: Bool) -> String? {
#if os(watchOS)
        return nil
#else
        let image: UIImage?
        if isAsset {
            image = UIImage(named: imageName)
        } else {
            let configuration = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
            image = UIImage(systemName: imageName, withConfiguration: configuration)
        }

        return encodeImage(image, alt: imageName)
#endif
    }

#if !os(watchOS)
    private func encodeImage(_ image: UIImage?, alt: String) -> String? {
        guard let image else { return nil }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let rendered = renderer.image { context in
            (UIColor(named: "AccentColor") ?? .systemBlue).setFill()
            guard let cgImage = image.cgImage else {
                image.draw(in: CGRect(origin: .zero, size: image.size))
                return
            }
            context.cgContext.translateBy(x: 0, y: image.size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            context.cgContext.setBlendMode(.normal)
            let rect = CGRect(origin: .zero, size: image.size)
            context.cgContext.clip(to: rect, mask: cgImage)
            context.cgContext.fill(rect)
        }

        guard let base64 = rendered.pngData()?.base64EncodedString() else { return nil }
        return "<img class='help-icon' style='height:1em;width:auto;vertical-align:-0.125em' src='data:image/png;base64,\(base64)' alt='\(alt)'/>"
    }
#endif

}
