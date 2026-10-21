import SwiftUI
import Testing
@testable import SBJLocalization

@Suite("Pending alert view modifier")
struct PendingAlertViewModifierTests {
    @MainActor
    @Test func pendingAlertViewModifierRetainsEstablishedSurface() {
        _ = Text("Value").pendingAlert(Binding<PendingAlert?>.constant(nil))
    }
}
