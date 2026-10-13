#if !os(tvOS) && !os(watchOS)
import SwiftUI

private struct SBJEditorDisclosureModeKey: EnvironmentKey {
    static let defaultValue: SBJEditorDisclosureMode = .closed
}

extension EnvironmentValues {
    var sbjEditorDisclosureMode: SBJEditorDisclosureMode {
        get { self[SBJEditorDisclosureModeKey.self] }
        set { self[SBJEditorDisclosureModeKey.self] = newValue }
    }
}
#endif
