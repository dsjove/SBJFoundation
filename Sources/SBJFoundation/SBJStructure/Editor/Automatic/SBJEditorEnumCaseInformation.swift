import Foundation
import SBJDataDefinition
import SBJLocalization

/// The exact case identity travels with its presentation metadata so a missing
/// custom title can fall back to the source case name.
struct SBJEditorSelectedCaseInfo {
    let sourceName: String
    let info: SBJPropertyInfo

    var title: String { info.title ?? sourceName.uncamelCased }
}

/// Resolves metadata using the concrete value's source-level enum case identity.
/// Optionals are unwrapped so a populated optional enum can show its selected case.
enum SBJEditorEnumCaseInformation {
    static func info(for value: Any) -> SBJEditorSelectedCaseInfo? {
        if let enumValue = value as? any SBJEnumCaseIdentifiable {
            let sourceName = enumValue.sbjCaseName
            guard let info = type(of: enumValue).sbjCaseInfo(for: sourceName) else { return nil }
            return .init(sourceName: sourceName, info: info)
        }
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional, let child = mirror.children.first else { return nil }
        return info(for: child.value)
    }
}
