import Testing
@testable import SBJStructuredAI

import SwiftUI

@Suite("Availability view construction")
@MainActor
struct SBJAssistantAvailabilityViewTests {
    @Test(arguments: [SBJAssistantState.unsupported, .disabled, .preparing, .ready, .unknown])
    func buildsView(state: SBJAssistantState) {
        let view = SBJAssistantAvailabilityView(state: state)
        #expect(view.state == state)
        _ = view.body
    }
}
