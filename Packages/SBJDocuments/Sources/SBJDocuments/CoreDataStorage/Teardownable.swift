import Foundation

/// A model or resource that needs explicit relationship/resource cleanup as part
/// of deletion.
public protocol Teardownable {
    func tearDown()

    /// Transitional compatibility for apps that still use the historical
    /// convention where `tearDown()` also deletes the receiver.
    ///
    /// New code should return `false`: teardown then means "prepare for
    /// deletion," and `PersistentModel.deleteNow()` performs the actual delete.
    var tearDownDeletesSelf: Bool { get }
}

public extension Teardownable {
    var tearDownDeletesSelf: Bool { true }
}

/// Historical spelling retained while existing apps migrate.
public typealias TearDownable = Teardownable

public extension Array where Element: Teardownable {
    mutating func tearDown() {
        let elements = self
        removeAll(keepingCapacity: false)
        elements.forEach { $0.tearDown() }
    }
}

// TODO(CoreDataStorage lifecycle): After the remaining CoreData/CloudKit apps
// migrate, remove `tearDownDeletesSelf`, make preparation-only teardown the sole
// contract, and remove the historical TearDownable spelling.
