#if !os(tvOS) && !os(watchOS)
import SwiftUI

/// A deliberately type-erased binding used only to cross heterogeneous editor
/// dispatch boundaries.
///
/// The concrete value type is recorded when the binding is erased. Recovery is
/// centralized here so editor implementations do not repeatedly erase and
/// force-cast bindings themselves.
public struct SBJAnyBinding {
    public let valueType: Any.Type

    private let getter: @MainActor () -> Any
    private let setter: @MainActor (Any) -> Bool

    @MainActor
    public init<Value>(_ binding: Binding<Value>) {
        valueType = Value.self
        getter = { binding.wrappedValue }
        setter = { value in
            guard let typed = value as? Value else { return false }
            binding.wrappedValue = typed
            return true
        }
    }

    @available(*, deprecated, message: "Recover a typed Binding with binding(as:) instead of reading the erased value directly.")
    @MainActor
    public func get() -> Any { getter() }

    @available(*, deprecated, message: "Recover a typed Binding with binding(as:) instead of mutating the erased value directly.")
    @MainActor
    public func set(_ value: Any) {
        precondition(
            setter(value),
            "SBJAnyBinding setter rejected \(String(describing: Swift.type(of: value))) for stored type \(String(describing: valueType))"
        )
    }

    /// Recovers the concrete binding after existential dispatch has established
    /// its type. A mismatched request is an internal editor contract violation
    /// and reports both types instead of failing at an opaque cast.
    @MainActor
    public func binding<Value>(as type: Value.Type = Value.self) -> Binding<Value> {
        precondition(
            ObjectIdentifier(valueType) == ObjectIdentifier(type),
            "SBJAnyBinding type mismatch: stored \(String(describing: valueType)), requested \(String(describing: type))"
        )

        return Binding<Value>(
            get: {
                guard let value = getter() as? Value else {
                    preconditionFailure(
                        "SBJAnyBinding getter returned \(String(describing: Swift.type(of: getter()))) for stored type \(String(describing: valueType))"
                    )
                }
                return value
            },
            set: { newValue in
                precondition(
                    setter(newValue),
                    "SBJAnyBinding setter rejected \(String(describing: Value.self)) for stored type \(String(describing: valueType))"
                )
            }
        )
    }
}

extension Binding {
    /// Reinterprets a binding only when the source and destination are the same
    /// runtime Swift type. This is used by generic scalar dispatch after an
    /// explicit `Value.self == Concrete.self` check.
    @MainActor
    func sbjBinding<Other>(as type: Other.Type = Other.self) -> Binding<Other> {
        precondition(
            ObjectIdentifier(Value.self) == ObjectIdentifier(type),
            "Binding type mismatch: stored \(String(describing: Value.self)), requested \(String(describing: type))"
        )

        return Binding<Other>(
            get: {
                guard let value = wrappedValue as? Other else {
                    preconditionFailure(
                        "Binding getter could not recover \(String(describing: Other.self)) from \(String(describing: Value.self))"
                    )
                }
                return value
            },
            set: { newValue in
                guard let value = newValue as? Value else {
                    preconditionFailure(
                        "Binding setter could not assign \(String(describing: Other.self)) to \(String(describing: Value.self))"
                    )
                }
                wrappedValue = value
            }
        )
    }
}
#endif
