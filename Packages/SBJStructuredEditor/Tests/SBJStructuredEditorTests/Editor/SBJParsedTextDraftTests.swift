import Foundation
import Testing
@testable import SBJStructuredEditor

@Test("Invalid intermediate input does not replace the last valid parsed value")
func parsedTextDraftPreservesModelValue() {
    let original = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
    let replacement = UUID(uuidString: "89ABCDEF-0123-4567-89AB-CDEF01234567")!
    var model = original
    var draft = SBJParsedTextDraft()
    draft.reset(to: model.uuidString)

    // Partial replacement is an ordinary editing state, not a valid UUID.
    if let parsed = draft.edit("89ABCDEF-", parse: { UUID(uuidString: $0) }) {
        model = parsed
    }
    #expect(draft.text == "89ABCDEF-")
    #expect(!draft.isValid)
    #expect(model == original)

    if let parsed = draft.edit(replacement.uuidString, parse: { UUID(uuidString: $0) }) {
        model = parsed
    }
    #expect(draft.isValid)
    #expect(model == replacement)

    // When the editor relinquishes focus, it replaces any unfinished draft
    // with the current model representation.
    _ = draft.edit("not-a-uuid", parse: { UUID(uuidString: $0) })
    draft.reset(to: model.uuidString)
    #expect(draft.isValid)
    #expect(draft.text == replacement.uuidString)
}
