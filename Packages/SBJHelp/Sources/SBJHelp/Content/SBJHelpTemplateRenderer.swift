import Foundation
import SBJLocalization
import SBJFileResources


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
        var values = [
            "TITLE": asset.displayName,
            "DISPLAY_NAME": "",
            "VERSION": "",
            "COMPANY_NAME": "",
            "EMAIL": "",
            "URL": "",
            "PRIVACY_URL": "",
            "ICON": "",
            "STYLE_SHEET": SBJHelpSharedStyleSheet.css + "\n" + (configuration.styleSheetAsset?.stringValue() ?? ""),
        ]
        values.merge(configuration.applicationSubstitutions) { _, new in new }
        return values
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
            // Expand complete entries before images; no duplicated explanatory prose.
            rendered = replacingNomenclatureEntries(in: rendered)
            var imageReplacements = extractHTMLImageSubstitutions(from: rendered)
            imageReplacements.merge(extractSemanticImageSubstitutions(from: rendered)) { _, new in new }
            rendered = rendered.replacingOccurrences(using: imageReplacements)
        }
        return rendered
    }


    /// Substitutes NOM_<stableID>\ tokens with semantic HTML styled by STYLE_SHEET.
    /// An unknown ID is retained visibly to make missing registrations detectable.
    func replacingNomenclatureEntries(in html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"NOM_([a-zA-Z0-9._-]+)\\"#) else { return html }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..<html.endIndex, in: html))
        var result = html
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let keyRange = Range(match.range(at: 1), in: result) else { continue }
            let key = String(result[keyRange])
            guard let item = configuration.nomenclatures[key] else { continue }
            let title = escapeHTML((item.nonEmptyTitle ?? key))
            let summary = item.summary.map(escapeHTML)
            let details = item.details.map(escapeHTML)
            var parts: [String] = []
            if let symbol = item.symbol {
                #if !os(watchOS)
                if let image = encodeImage(symbol.nativeImage, alt: (item.nonEmptyTitle ?? key)) {
                    parts.append(image)
                }
                #endif
            }
            parts.append("<span class=\"sbj-nomenclature-title\">\(title)</span>")
            var entry = "<section class=\"sbj-nomenclature\" data-nomenclature=\"\(escapeHTML(key))\"><div class=\"sbj-nomenclature-heading\">\(parts.joined())</div>"
            if let summary { entry += "<p class=\"sbj-nomenclature-summary\">\(summary)</p>" }
            if let details { entry += "<p class=\"sbj-nomenclature-details\">\(details.replacingOccurrences(of: "\n", with: "<br>"))</p>" }
            entry += "</section>"
            result.replaceSubrange(fullRange, with: entry)
        }
        return result
    }

    private func escapeHTML(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
             .replacingOccurrences(of: "\"", with: "&quot;")
             .replacingOccurrences(of: "'", with: "&#39;")
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
                    reference.nativeImage,
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
        let symbol: SBJSymbol = isAsset ? .asset(imageName, bundle: nil) : .system(imageName)
        return encodeImage(symbol.nativeImage, alt: imageName)
#endif
    }

#if !os(watchOS)
    private func encodeImage(_ image: SBJImage?, alt: String) -> String? {
        guard let base64 = SBJHelpImageEncoding.pngData(for: image)?.base64EncodedString() else { return nil }
        return "<img class='help-icon' src='data:image/png;base64,\(base64)' alt='\(escapeHTML(alt))'/>"
    }
#endif
}
