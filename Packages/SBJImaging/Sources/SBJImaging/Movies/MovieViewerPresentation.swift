#if os(macOS) || os(iOS) || os(visionOS)
import SwiftUI
import Observation
import SBJFileResources
import CoreGraphics

/// A movie request is independent of Casting or of the owning SwiftUI view.
/// An ID instead of URL as the scene value permits multiple windows for one movie.
public struct MovieViewerSheet: Identifiable {
    public let id: UUID
}

/// A request to play a movie stored inside an authorized directory.
/// Opening web links and other files is handled separately by the caller.
public struct MediaOpenRequest: Identifiable {
    public let id = UUID()
    public let title: String
    public let file: ScopedFile
    public let initialTime: TimeInterval?
    public let options: MovieViewerOptions
    public let setPoster: MoviePosterHandler?

    public init(
        title: String,
        file: ScopedFile,
        initialTime: TimeInterval? = nil,
        options: MovieViewerOptions = .init(),
        setPoster: MoviePosterHandler? = nil
    ) {
        self.title = title
        self.file = file
        self.initialTime = initialTime
        self.options = options
        self.setPoster = setPoster
    }
}

@MainActor
struct MovieViewerSession {
    let title: String
    let url: URL
    let initialTime: TimeInterval?
    let options: MovieViewerOptions
    let setPoster: MoviePosterHandler?
    /// Retained while the player may access the movie file.
    let accessLease: SecurityScopedFileURLLease
}

@MainActor
@Observable
public final class MovieViewerSessions {
    public static let sceneID = "movie-viewer"

    private(set) var sessions: [UUID: MovieViewerSession] = [:]

    public init() {}

    // A pending request is registered before the URL binding changes. This
    // preserves the title, casting callback and scoped directory access while
    // keeping the presentation API as simple as quickLookPreview($url).
    private var pending: (title: String, resource: SecurityScopedFileURL,
                          initialTime: TimeInterval?, options: MovieViewerOptions,
                          setPoster: MoviePosterHandler?)?

    func prepare(title: String, resource: SecurityScopedFileURL, initialTime: TimeInterval?,
                 options: MovieViewerOptions = .init(), setPoster: MoviePosterHandler?) {
        pending = (title, resource, initialTime, options, setPoster)
    }

    func openPrepared(for url: URL) -> UUID {
        guard let request = pending, request.resource.url == url else {
            return open(title: url.deletingPathExtension().lastPathComponent,
                        resource: SecurityScopedFileURL(url), initialTime: nil)
        }
        pending = nil
        return open(title: request.title, resource: request.resource,
                    initialTime: request.initialTime, options: request.options,
                    setPoster: request.setPoster)
    }

    @discardableResult
    func open(
        title: String,
        resource: SecurityScopedFileURL,
        initialTime: TimeInterval?,
        options: MovieViewerOptions = .init(),
        setPoster: MoviePosterHandler? = nil
    ) -> UUID {
        // Keep the security scope alive until the window/sheet closes.
        let access = resource.beginAccess()
        let id = UUID()
        sessions[id] = MovieViewerSession(
            title: title, url: resource.url, initialTime: initialTime,
            options: options, setPoster: setPoster, accessLease: access
        )
        return id
    }

    func close(_ id: UUID) {
        sessions.removeValue(forKey: id)
    }
}

/// Same player in both a SwiftUI WindowGroup and the single-window fallback.
/// The presenting scene owns dismissal; the session owns security-scoped access.
public struct MovieViewerSessionContent: View {
    let id: UUID
    let sessions: MovieViewerSessions
    @Environment(\.dismiss) private var dismiss

    public init(id: UUID, sessions: MovieViewerSessions) {
        self.id = id
        self.sessions = sessions
    }

    public var body: some View {
        Group {
            if let session = sessions.sessions[id] {
                MovieViewer(
                    title: session.title,
                    url: session.url,
                    initialTime: session.initialTime,
                    options: session.options,
                    onClose: { dismiss() },
                    setPoster: session.setPoster
                )
            } else {
                // An old/restored window has no matching live session.
                ContentUnavailableView("Movie unavailable", systemImage: "film")
                    .task { dismiss() }
            }
        }
        .frame(minWidth: 320, minHeight: 220)
        .onDisappear { sessions.close(id) }
    }
}
/// Presents movies with the same URL-binding interface as quickLookPreview.
/// The binding is cleared when the viewer closes and can be cleared by the
/// caller to dismiss it. Rich metadata may be staged in MovieViewerSessions
/// before assigning the URL; an ordinary URL works without staging.
@MainActor
private struct MovieViewerModifier: ViewModifier {
    @Binding var url: URL?
    let sessions: MovieViewerSessions
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    @State private var presentedID: UUID?
    @State private var sheetSelection: MovieViewerSheet?

    func body(content: Content) -> some View {
        content
            .sheet(item: $sheetSelection) { selection in
                MovieViewerSessionContent(id: selection.id, sessions: sessions)
            }
            .onChange(of: url, initial: true) { _, next in
                updatePresentation(for: next)
            }
            .onChange(of: presentedID.flatMap { sessions.sessions[$0] } == nil) { _, missing in
                // WindowGroup dismissal removes the session onDisappear.
                // Reset the binding, just as Quick Look does on dismissal.
                if missing, presentedID != nil {
                    presentedID = nil
                    sheetSelection = nil
                    url = nil
                }
            }
    }

    private func updatePresentation(for next: URL?) {
        if let oldID = presentedID {
            // A nil URL explicitly dismisses the current viewer. Changing to
            // another URL closes the old viewer before opening the next one.
            if next == nil || sessions.sessions[oldID]?.url != next {
                sheetSelection = nil
                dismissWindow(id: MovieViewerSessions.sceneID, value: oldID)
                sessions.close(oldID)
                presentedID = nil
            } else {
                return
            }
        }

        guard let next else { return }
        let id = sessions.openPrepared(for: next)
        presentedID = id
        #if targetEnvironment(macCatalyst) || os(visionOS)
        openWindow(id: MovieViewerSessions.sceneID, value: id)
        #else
        if supportsMultipleWindows {
            openWindow(id: MovieViewerSessions.sceneID, value: id)
        } else {
            sheetSelection = MovieViewerSheet(id: id)
        }
        #endif
    }
}

/// Movie presentation uses a caller-owned session store passed explicitly.
/// ContentView does not have to stage requests separately.
@MainActor
private struct MediaOpenRequestModifier: ViewModifier {
    @Binding var request: MediaOpenRequest?
    let sessions: MovieViewerSessions
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    @State private var presentedID: UUID?
    @State private var sheetSelection: MovieViewerSheet?

    func body(content: Content) -> some View {
        content
            .sheet(item: $sheetSelection) { selection in
                MovieViewerSessionContent(id: selection.id, sessions: sessions)
            }
            .onChange(of: request?.id, initial: true) { _, _ in
                updatePresentation()
            }
            .onChange(of: presentedID.flatMap { sessions.sessions[$0] } == nil) { _, missing in
                if missing, presentedID != nil {
                    presentedID = nil
                    sheetSelection = nil
                    request = nil
                }
            }
    }

    private func updatePresentation() {
        if let oldID = presentedID {
            sheetSelection = nil
            dismissWindow(id: MovieViewerSessions.sceneID, value: oldID)
            sessions.close(oldID)
            presentedID = nil
        }

        guard let request else { return }
        let id = sessions.open(
            title: request.title, resource: request.file.securityScopedURL,
            initialTime: request.initialTime, options: request.options,
            setPoster: request.setPoster
        )
        presentedID = id
        #if targetEnvironment(macCatalyst) || os(visionOS)
        openWindow(id: MovieViewerSessions.sceneID, value: id)
        #else
        if supportsMultipleWindows {
            openWindow(id: MovieViewerSessions.sceneID, value: id)
        } else {
            sheetSelection = MovieViewerSheet(id: id)
        }
        #endif
    }
}

extension View {
    /// Presents a local movie request without exposing MovieViewerSessions to the caller.
    public func movieViewer(_ request: Binding<MediaOpenRequest?>, sessions: MovieViewerSessions) -> some View {
        modifier(MediaOpenRequestModifier(request: request, sessions: sessions))
    }

    /// Displays a URL in the app's MovieViewer, using a window when supported
    /// and a sheet otherwise. Catalyst always opens a window. Set the binding to nil to dismiss.
    public func movieViewer(_ url: Binding<URL?>, sessions: MovieViewerSessions) -> some View {
        modifier(MovieViewerModifier(url: url, sessions: sessions))
    }
}

#endif
