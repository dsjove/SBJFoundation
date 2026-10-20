import Foundation
import Testing
import SBJHelp
@testable import SBJStructuredEditor

@Test func editorHelpFragmentsAreRegisteredAndResolvable() {
    var configuration = SBJHelpConfiguration.standard
    configuration.includeStructuredEditorHelp()
    let renderer = SBJHelpTemplateRenderer(configuration: configuration)
    let core = configuration.embeddedAssets["SBJ_STRUCTURE_EDITOR_CORE_HELP"]
    let search = configuration.embeddedAssets["SBJ_STRUCTURE_EDITOR_SEARCH_HELP"]
    #expect(core != nil)
    #expect(search != nil)
    if let core { #expect(renderer.renderedSource(for: core) != nil) }
    if let search { #expect(renderer.renderedSource(for: search) != nil) }
}
