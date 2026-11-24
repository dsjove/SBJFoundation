import Foundation

/// Shared, bundled CSS for all SBJHelp HTML documents.
/// Page templates use `<style>STYLE_SHEET</style>`; no page owns presentation rules.
public enum SBJHelpSharedStyleSheet {
    public static var css: String {
        guard let url = Bundle.module.url(forResource: "Help", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return css
    }
}
