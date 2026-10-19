import Foundation
import SBJDataDefinition
import Observation

/// Lifetime token for an observation installed by ``observeValue``.
///
/// Cancellation is synchronous: once `cancel()` returns, callbacks scheduled
/// after that point will not be delivered. A callback already executing on the
/// main actor is allowed to finish.
public final class ObserveToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public func cancel() {
        lock.withLock { cancelled = true }
    }

    fileprivate var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    deinit {
        cancel()
    }
}

/// Owns the deliberately non-Sendable observation ingredients. Observation's
/// `onChange` callback is Sendable, so it captures only this explicitly managed
/// box and hops to the main actor before touching the source, key path, or
/// callback.
private final class ObserveValueState<S: AnyObject, C: AnyObject, V>: @unchecked Sendable {
    weak var source: S?
    weak var context: C?
    let requiresContext: Bool
    let path: KeyPath<S, V>
    let token: ObserveToken
    let change: @MainActor (S, V, C?) -> Void

    init(
        source: S,
        path: KeyPath<S, V>,
        context: C?,
        token: ObserveToken,
        change: @escaping @MainActor (S, V, C?) -> Void
    ) {
        self.source = source
        self.path = path
        self.context = context
        self.requiresContext = context != nil
        self.token = token
        self.change = change
    }

    @MainActor
    func push() {
        guard !token.isCancelled, let source else { return }
        guard !requiresContext || context != nil else { return }
        change(source, source[keyPath: path], context)
    }

    func track() {
        guard !token.isCancelled, let source else { return }
        guard !requiresContext || context != nil else { return }

        withObservationTracking {
            _ = source[keyPath: path]
        } onChange: { [self] in
            Task { @MainActor [self] in
                guard !token.isCancelled else { return }
                push()
                guard !token.isCancelled else { return }
                track()
            }
        }
    }
}


private final class ObserveNoContext {}

/// Context-free convenience overload. Use the `with:` overload when the
/// observation lifetime should also be tied weakly to a context object.
@discardableResult
public func observeValue<S: AnyObject, V>(
    of source: S?,
    _ path: KeyPath<S, V>,
    initialPush: Bool = true,
    change: @escaping @MainActor (S, V) -> Void
) -> ObserveToken {
    observeValue(
        of: source,
        path,
        with: nil as ObserveNoContext?,
        initialPush: initialPush
    ) { source, value, _ in
        change(source, value)
    }
}

/// Observes one Observation-tracked key path and re-arms tracking after each
/// change. The source is held weakly. When a context is supplied it is also held
/// weakly and observation ends when that context is released.
///
/// The value and callback are delivered on the main actor, matching the common
/// UI use case for this helper.
@discardableResult
public func observeValue<S: AnyObject, C: AnyObject, V>(
    of source: S?,
    _ path: KeyPath<S, V>,
    with context: C? = nil,
    initialPush: Bool = true,
    change: @escaping @MainActor (S, V, C?) -> Void
) -> ObserveToken {
    guard let source else { return ObserveToken() }

    let token = ObserveToken()
    let state = ObserveValueState(
        source: source,
        path: path,
        context: context,
        token: token,
        change: change
    )

    if initialPush {
        Task { @MainActor [state] in
            state.push()
            guard !token.isCancelled else { return }
            state.track()
        }
    } else {
        state.track()
    }

    return token
}
