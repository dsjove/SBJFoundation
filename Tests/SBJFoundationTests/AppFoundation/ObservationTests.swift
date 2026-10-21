import Observation
import XCTest
@testable import SBJFoundation

@Observable
private final class ObservationFixture {
    var value = 0
}

final class ObservationTests: XCTestCase {
    @MainActor
    func testContextlessObservationRearmsAfterChange() async {
        let model = ObservationFixture()
        let first = expectation(description: "first change")
        let second = expectation(description: "second change")
        var received: [Int] = []

        let token = SBJFoundation.observeValue(of: model, \ObservationFixture.value, initialPush: false) { _, value in
            received.append(value)
            if value == 1 { first.fulfill() }
            if value == 2 { second.fulfill() }
        }

        model.value = 1
        await fulfillment(of: [first], timeout: 1.0)
        model.value = 2
        await fulfillment(of: [second], timeout: 1.0)

        XCTAssertTrue(received.contains(1))
        XCTAssertTrue(received.contains(2))
        token.cancel()
    }

    @MainActor
    func testCancellationSuppressesFutureDelivery() async {
        let model = ObservationFixture()
        let unexpected = expectation(description: "cancelled observer does not fire")
        unexpected.isInverted = true

        let token = SBJFoundation.observeValue(of: model, \ObservationFixture.value, initialPush: false) { _, _ in
            unexpected.fulfill()
        }
        token.cancel()
        model.value = 1

        await fulfillment(of: [unexpected], timeout: 0.1)
    }
}
