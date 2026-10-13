#if !os(tvOS) && !os(watchOS)
import SwiftUI

public struct SBJEditorFormattingOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let trailingAlignedFields = Self(rawValue: 1 << 0)
}

private struct SBJEditorFormattingKey: EnvironmentKey {
    static let defaultValue: SBJEditorFormattingOptions = []
}

extension EnvironmentValues {
    var sbjEditorFormattingOptions: SBJEditorFormattingOptions {
        get { self[SBJEditorFormattingKey.self] }
        set { self[SBJEditorFormattingKey.self] = newValue }
    }
}

public extension View {
    func sbjEditorFormatting(_ options: SBJEditorFormattingOptions) -> some View {
        environment(\.sbjEditorFormattingOptions, options)
    }
}
#endif
