import Foundation
import SwiftUI
import Testing
@testable import SBJStructuredEditor
import SBJUIVocabulary
#if !os(tvOS) && !os(watchOS)

@MainActor
@Suite("Editor disclosure persistence")
struct SBJEditorExpansionPersistenceTests {
    @Test("Session-only state does not survive a new presentation model")
    func sessionOnly() {
        let id = SBJEditorItemIdentifier.root.appending("property:example")
        let first = SBJEditorPresentationModel(expansionOptions: .sessionOnly)
        first.setUserExpansion(true, for: id, search: false)
        #expect(first.isUserExpanded(id, mode: .closed))
        let second = SBJEditorPresentationModel(expansionOptions: .sessionOnly)
        #expect(!second.isUserExpanded(id, mode: .closed))
    }

    @Test("Saved choices reload and namespaces remain independent")
    func savedPreferences() {
        let suite = "SBJEditorExpansionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SBJEditorPreferencesExpansionStore(defaults: defaults)
        let id = SBJEditorItemIdentifier.root.appending("property:example")
        let a = SBJEditorExpansionOptions(store: store, namespace: "document-A")
        let b = SBJEditorExpansionOptions(store: store, namespace: "document-B")
        SBJEditorPresentationModel(expansionOptions: a)
            .setUserExpansion(true, for: id, search: false)
        #expect(SBJEditorPresentationModel(expansionOptions: a).isUserExpanded(id, mode: .closed))
        #expect(!SBJEditorPresentationModel(expansionOptions: b).isUserExpanded(id, mode: .closed))
    }

    @Test("Reading effective expansion does not persist transient expansion")
    func transientDisclosureReadDoesNotWritePreferences() {
        let suite = "SBJEditorExpansionReads.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SBJEditorPreferencesExpansionStore(defaults: defaults)
        let id = SBJEditorItemIdentifier.root.appending("property:temporary")
        let model = SBJEditorPresentationModel(
            expansionOptions: SBJEditorExpansionOptions(store: store)
        )

        #expect(model.resolved(id, mode: .closed, search: true, navigation: false))
        #expect(model.resolved(id, mode: .closed, search: false, navigation: true))
        #expect(!model.isUserExpanded(id, mode: .closed))
        #expect(store.expansion(for: id, namespace: nil) == nil)

        model.setUserExpansion(true, for: id, search: false)
        #expect(store.expansion(for: id, namespace: nil) == true)
    }

    @Test("Context-based expansion uses the same user choice as a disclosure binding")
    func contextBasedExpansion() {
        let model = SBJEditorPresentationModel(expansionOptions: .sessionOnly)
        let id = SBJEditorItemIdentifier.root.appending("property:context")
        let context = SBJEditTraversalContext(
            treeLevel: 1,
            itemIdentifier: id
        )
        #expect(!model.isExpanded(for: context))
        #expect(!model.disclosureBinding(for: context).wrappedValue)
        model.setUserExpansion(true, for: id, search: false)
        #expect(model.isExpanded(for: context))
        #expect(model.disclosureBinding(for: context).wrappedValue)
        model.setUserExpansion(false, for: id, search: false)
        #expect(!model.isExpanded(for: context))
    }

    @Test("Navigation and search never change saved choices")
    func transientExpansion() {
        let model = SBJEditorPresentationModel(expansionOptions: .sessionOnly)
        let id = SBJEditorItemIdentifier.root.appending("property:example")
        #expect(model.resolved(id, mode: .closed, search: false, navigation: true))
        #expect(model.resolved(id, mode: .closed, search: true, navigation: false))
        #expect(!model.isUserExpanded(id, mode: .closed))
        model.setUserExpansion(true, for: id, search: true)
        #expect(!model.isUserExpanded(id, mode: .closed))
    }
}
#endif
