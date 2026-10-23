import SBJHelp
import SBJLocalization

public extension SBJHelpConfiguration {
    /// Help configuration for image import, viewing, and editing UI.
    static var image: Self {
        var configuration = Self.standard
        configuration.addSymbolSet(SBJImageSymbology.self)
        return configuration
    }
}
