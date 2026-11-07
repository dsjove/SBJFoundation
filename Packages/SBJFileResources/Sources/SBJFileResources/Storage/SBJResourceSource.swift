import Foundation

/// Immediate content or an asynchronously readable and writable resource.
/// `hasContent` is a cheap availability hint: nil means unknown, not absent.
/// Availability is supplied by the owner and is not cached here.
public enum SBJResourceSource {
    case content(SBJResourceContent?)
    case deferred(
        hasContent: Bool?,
        load: @MainActor @Sendable () async throws -> SBJResourceContent?,
        save: @MainActor @Sendable (SBJResourceContent?) async throws -> Void
    )

    public var hasContent: Bool? {
        switch self {
        case .content(let content): content != nil
        case .deferred(let available, _, _): available
        }
    }

    @MainActor
    public func resolve() async throws -> SBJResourceContent? {
        switch self {
        case .content(let content): content
        case .deferred(_, let load, _): try await load()
        }
    }

    @MainActor
    public func save(_ content: SBJResourceContent?) async throws {
        switch self {
        case .content:
            throw NSError(domain: "SBJResourceSource", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Immediate content is read-only; use a deferred source for edits."])
        case .deferred(_, _, let save):
            try await save(content)
        }
    }
}
