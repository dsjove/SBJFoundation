import Testing
@testable import SBJStructuredAI

@Suite("Assistant availability policy")
struct SBJAssistantStateTests {
    @Test("Unsupported hides the entry point and prohibits chat")
    func unsupported() {
        let state = SBJAssistantState.unsupported
        #expect(!state.isVisible)
        #expect(!state.canChat)
        #expect(!state.showsProgress)
    }

    @Test("Disabled backend remains discoverable without chat")
    func disabled() {
        let state = SBJAssistantState.disabled
        #expect(state.isVisible)
        #expect(!state.canChat)
        #expect(!state.showsProgress)
    }

    @Test("Preparing remains discoverable with indeterminate progress")
    func preparing() {
        let state = SBJAssistantState.preparing
        #expect(state.isVisible)
        #expect(!state.canChat)
        #expect(state.showsProgress)
    }

    @Test("Ready permits chat; unknown remains discoverable without chat or progress")
    func otherStates() {
        #expect(SBJAssistantState.ready.isVisible)
        #expect(SBJAssistantState.ready.canChat)
        #expect(!SBJAssistantState.ready.showsProgress)
        #expect(SBJAssistantState.unknown.isVisible)
        #expect(!SBJAssistantState.unknown.canChat)
        #expect(!SBJAssistantState.unknown.showsProgress)
    }

    @Test(arguments: [SBJAssistantState.ready, .unsupported, .disabled, .preparing, .unknown])
    func prewarmPolicy(state: SBJAssistantState) {
        #expect(state.canPrewarm(hasSession: false, isResponding: false) == (state == .ready))
        #expect(!state.canPrewarm(hasSession: true, isResponding: false))
        #expect(!state.canPrewarm(hasSession: false, isResponding: true))
        #expect(!state.canPrewarm(hasSession: true, isResponding: true))
    }

}
