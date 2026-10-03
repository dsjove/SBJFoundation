#if !os(tvOS) && !os(watchOS)
import Foundation

/// A problem with the SwiftUI editor's ability to represent a value.
///
/// This is deliberately separate from structural validation. Another editor
/// client can have different rendering capabilities while sharing the same
/// `SBJStructureDiagnostics` results.
public enum SBJEditorCapabilityIssueKind: Hashable, Sendable {
    case unsupported
}

public typealias SBJEditorCapabilityIssue = SBJIssue<SBJEditorCapabilityIssueKind>

public extension SBJIssue where Kind == SBJEditorCapabilityIssueKind {
    init(path: String, typeName: String, valueDescription: String?) {
        self.init(kind: .unsupported, path: path, typeName: typeName, valueDescription: valueDescription)
    }
}

/// SwiftUI-specific capability diagnostics only.
public enum SBJEditorCapabilityDiagnostics {
    @MainActor
    public static func issues<Value: SBJSwiftUIEditable>(
        for value: Value,
        registry: SBJEditorRegistry = .init()
    ) -> [SBJEditorCapabilityIssue] {
        var collection = SBJIssueCollection<SBJEditorCapabilityIssue>()
        collection.append(contentsOf: Value.sbjEditorFields.flatMap { field in
            field.issues(root: value, path: [], registry: registry)
        })
        return SBJEditorCapabilityIssue.removingRedundantIssues(from: collection.uniqued { $0 })
    }
}

/// Issue kinds displayed by the stock SwiftUI editor issue list.
public enum SBJEditorIssueKind: Hashable, Sendable {
    case unsupported
    case validation
}

public typealias SBJEditorIssue = SBJIssue<SBJEditorIssueKind>

public extension SBJIssue where Kind == SBJEditorIssueKind {
    init(path: String, typeName: String, valueDescription: String?, kind: Kind = .unsupported) {
        self.init(kind: kind, path: path, typeName: typeName, valueDescription: valueDescription)
    }

    static func validation(path: String, valueDescription: String? = nil, message: String) -> Self {
        .init(
            kind: .validation,
            path: path,
            typeName: "Validation",
            valueDescription: valueDescription,
            message: message
        )
    }
}

/// Convenience aggregation for the stock SwiftUI editor UI.
///
/// Validation comes exclusively from `SBJStructureDiagnostics`; editor
/// capability comes exclusively from `SBJEditorCapabilityDiagnostics`.
public enum SBJEditorDiagnostics {
    @MainActor
    public static func issues<Value: SBJSwiftUIEditable>(
        for value: Value,
        registry: SBJEditorRegistry = .init()
    ) -> [SBJEditorIssue] {
        var collection = SBJIssueCollection<SBJEditorIssue>()
        collection.append(contentsOf: SBJEditorCapabilityDiagnostics.issues(for: value, registry: registry).map { issue in
            SBJEditorIssue(
                kind: .unsupported,
                path: issue.path,
                typeName: issue.typeName,
                valueDescription: issue.valueDescription,
                message: issue.message
            )
        })
        collection.append(contentsOf: SBJStructureDiagnostics.issues(for: value).map { issue in
            SBJEditorIssue(
                kind: .validation,
                path: issue.path,
                typeName: issue.typeName,
                valueDescription: issue.valueDescription,
                message: issue.message
            )
        })
        return SBJEditorIssue.removingRedundantIssues(from: collection.uniqued { $0 })
    }
}

import SwiftUI

private struct SBJEditorShowIssuesKey: EnvironmentKey {
    static let defaultValue: @MainActor () -> Void = {}
}

extension EnvironmentValues {
    var sbjEditorShowIssues: @MainActor () -> Void {
        get { self[SBJEditorShowIssuesKey.self] }
        set { self[SBJEditorShowIssuesKey.self] = newValue }
    }
}

public struct SBJEditorIssueList: View {
    public let issues: [SBJEditorIssue]
    private let navigate: ((SBJEditorIssue) -> Void)?

    public init(
        issues: [SBJEditorIssue],
        navigate: ((SBJEditorIssue) -> Void)? = nil
    ) {
        self.issues = issues
        self.navigate = navigate
    }
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if issues.isEmpty {
                        Text("No editor issues.")
                            .foregroundStyle(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(issues) { issue in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(issue.path).fontWeight(.semibold)
                                Text(issue.typeName).foregroundStyle(.secondary)
                                if let valueDescription = issue.valueDescription {
                                    if issue.kind == .validation {
                                        Text("Value: \(valueDescription)").foregroundStyle(.secondary)
                                    } else {
                                        Text(valueDescription).italic().foregroundStyle(.secondary)
                                    }
                                }
                                if let message = issue.message {
                                    Text(message).italic().foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if let navigate {
                                SBJImageButton(
                                    SBJSemanticImageReference.navigateToProperty,
                                    accessibilityLabel: "Go to \(issue.path)",
                                    accessibilityHint: "Closes the issue viewer and reveals this property in the editor"
                                ) {
                                    navigate(issue)
                                }
                            }
                        }
                        if issue.id != issues.last?.id { Divider() }
                    }
                }
                .padding()
            }
            .navigationTitle("Editor Issues")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif
