import Foundation
import XCTest
@testable import SBJFileResources

final class DefaultsStorageTests: XCTestCase {
    func testBooleanStorageAndDefaultValue() {
        let suite = "SBJFileResources.DefaultsStorageTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Could not create test UserDefaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = DefaultsStorage<Bool>(wrappedValue: false, "hasShownHelp", store: defaults)
        XCTAssertFalse(storage.wrappedValue)
        storage.wrappedValue = true
        XCTAssertTrue(DefaultsStorage<Bool>(wrappedValue: false, "hasShownHelp", store: defaults).wrappedValue)
        storage.erase()
        XCTAssertFalse(storage.wrappedValue)
    }
}
