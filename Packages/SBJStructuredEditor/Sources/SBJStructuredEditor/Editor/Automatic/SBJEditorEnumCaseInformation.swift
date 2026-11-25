#if !os(tvOS) && !os(watchOS)
import SBJStructure
import Foundation
import SBJUIVocabulary

/// The exact case identity travels with its presentation metadata so a missing
/// custom title can fall back to the source case name.
struct SBJEditorSelectedCaseInfo {
    let sourceName: String
    let info: SBJNomenclature

    var title: String { info.nonEmptyTitle ?? sourceName.uncamelCased }
}

/// Resolves metadata using the concrete value's source-level enum case identity.
/// Optionals are unwrapped so a populated optional enum can show its selected case.
enum SBJEditorEnumCaseInformation {
    static func info(for value: Any) -> SBJEditorSelectedCaseInfo? {
        if let enumValue = value as? any SBJEnumCaseIdentifiable {
            let sourceName = enumValue.sbjCaseName
            guard let info = type(of: enumValue).sbjCaseNomenclature(for: sourceName) else { return nil }
            return .init(sourceName: sourceName, info: info)
        }
        guard case .optional? = SBJStructuralType.container(of: type(of: value)),
              let container = value as? any SBJStructuralValueContainer,
              let child = container.sbjStructuralChildren(itemTitleKey: nil, itemIdentifierKey: nil).first
        else { return nil }
        return info(for: child.value)
    }
}
#endif
