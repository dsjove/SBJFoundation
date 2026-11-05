#if os(macOS) || os(iOS) || os(visionOS)
import SwiftUI
import Observation
import AVFoundation
import AVKit
import SBJLocalization
import SBJDataDefinition
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Shared AVPlayer engine; only the compact controls are custom.
@MainActor
@Observable
final class MoviePlayback {
    let player: AVPlayer
    var seconds: Double = 0
    var duration: Double = 0
    var isPlaying = false
    var volume: Double = 1
    private var observer: Any?
    private var ending: NSObjectProtocol?
    private var durationTask: Task<Void, Never>?

    init(url: URL) {
        player = AVPlayer(url: url)
        observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30), queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.seconds = max(0, time.seconds.isFinite ? time.seconds : 0)
            }
        }
        if let item = player.currentItem {
            ending = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.isPlaying = false }
            }
        }
        durationTask = Task { [weak self] in
            guard let self, let item = self.player.currentItem,
                  let duration = try? await item.asset.load(.duration),
                  !Task.isCancelled else { return }
            let result = duration.seconds
            self.duration = result.isFinite && result > 0 ? result : 0
        }
    }

    /// Explicit cleanup on the main actor, since deinit isn't actor-isolated.
    func stopObserving() {
        durationTask?.cancel()
        durationTask = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        if let observer {
            player.removeTimeObserver(observer)
            self.observer = nil
        }
        if let ending {
            NotificationCenter.default.removeObserver(ending)
            self.ending = nil
        }
    }

    func toggle() {
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }
    func pause() { player.pause(); isPlaying = false }
    func seek(_ position: Double) {
        guard position.isFinite else { return }
        let bounded = min(max(0, position), duration > 0 ? duration : position)
        seconds = bounded
        player.seek(to: CMTime(seconds: bounded, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }
    func step(_ count: Int) {
        pause()
        player.currentItem?.step(byCount: count)
    }
}

#if os(macOS)
private struct NativeVideoSurface: NSViewRepresentable {
    let playback: MoviePlayback
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = playback.player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        return view
    }
    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== playback.player { view.player = playback.player }
    }
    static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) {
        view.player = nil
    }
}
#else
private struct NativeVideoSurface: UIViewControllerRepresentable {
    let playback: MoviePlayback
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = playback.player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== playback.player { controller.player = playback.player }
    }
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player = nil
    }
}
#endif

struct MovieViewer: View {
    let title: String
    let url: URL
    var initialTime: TimeInterval? = nil
    var onPosterChanged: (@MainActor (TimeInterval) async throws -> Bool)? = nil
    @State private var playback: MoviePlayback
    @State private var working = false
    @State private var errorMessage: String?
    var onClose: (() -> Void)? = nil
    var onFullScreen: (() -> Void)? = nil

    init(title: String, url: URL, initialTime: TimeInterval? = nil,
         onPosterChanged: (@MainActor (TimeInterval) async throws -> Bool)? = nil,
         onClose: (() -> Void)? = nil, onFullScreen: (() -> Void)? = nil) {
        self.title = title
        self.url = url
        self.initialTime = initialTime
        self.onPosterChanged = onPosterChanged
        self.onClose = onClose
        self.onFullScreen = onFullScreen
        _playback = State(initialValue: MoviePlayback(url: url))
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var fullscreen = false
    #if os(macOS)
    @State private var hostingWindow: NSWindow?
    #endif
    @Environment(\.dismiss) private var dismiss

    private var compact: Bool {
        #if os(macOS)
        false
        #else
        horizontalSizeClass == .compact
        #endif
    }

    private var videoSurface: some View {
        NativeVideoSurface(playback: playback)
            // The video can be 4:3, 16:9, CinemaScope, or portrait.
            // Fill the available layout; AVKit maintains the source aspect.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @State private var frameRepeatTask: Task<Void, Never>?
    @State private var activeFrameDirection: Int?

    private func stopFrameRepeat() {
        frameRepeatTask?.cancel()
        frameRepeatTask = nil
        activeFrameDirection = nil
    }

    private func beginFramePress(_ direction: Int) {
        guard activeFrameDirection == nil else { return }
        activeFrameDirection = direction
        playback.step(direction) // Immediately respond to a tap.
        frameRepeatTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { break }
                playback.step(direction)
            }
        }
    }

    private func frameButton(_ direction: Int, symbol: String, title: String) -> some View {
        Button { playback.step(direction) } label: {
            Image(systemName: symbol)
                .contentShape(Rectangle())
        }
        // High-priority zero-distance drag handles mouse/touch hold. The Button
        // action remains available for keyboard and accessibility activation.
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginFramePress(direction) }
                .onEnded { _ in stopFrameRepeat() }
        )
        .help(title)
    }

    private var playbackButtons: some View {
        HStack(spacing: 6) {
            frameButton(-1, symbol: "backward.frame", title: "Previous frame")
            Button { playback.toggle() } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
            }.help("Play or pause")
            frameButton(1, symbol: "forward.frame", title: "Next frame")
        }
    }

    private var timeline: some View {
        Slider(value: Binding(
            get: { min(playback.seconds, max(playback.duration, 0.001)) },
            set: { playback.seek($0) }
        ), in: 0...max(playback.duration, 0.001))
    }

    private var remainingControls: some View {
        HStack(spacing: 7) {
            Image(systemName: "speaker.wave.2")
            Slider(value: $playback.volume, in: 0...1)
                .frame(width: compact ? 58 : 68)
                .onChange(of: playback.volume) { _, next in
                    playback.player.volume = Float(next)
                }
            Button {
                #if os(macOS)
                if let onFullScreen { onFullScreen() }
                else { hostingWindow?.toggleFullScreen(nil) }
                #else
                fullscreen = true
                #endif
            } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
            .help("Full screen")
            if onPosterChanged != nil {
                Button { Task { await savePoster() } } label: { Image(systemName: "camera") }
                    .help("Select current frame").disabled(working)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 9) {
            Button { if let onClose { onClose() } else { dismiss() } } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Close movie")
            Group {
            if compact {
                VStack(spacing: 4) {
                    HStack(spacing: 7) {
                        playbackButtons
                        timeline
                        Text(playback.seconds.timestampString)
                            .monospacedDigit().frame(minWidth: 65, alignment: .leading)
                    }
                    remainingControls
                }
            } else {
                HStack(spacing: 7) {
                    playbackButtons
                    timeline
                    Text(playback.seconds.timestampString)
                        .monospacedDigit().frame(minWidth: 74, alignment: .leading)
                    remainingControls
                }
            }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black)
    }

    private var movieTitle: some View {
        // Single shared caption for regular and fullscreen presentation.
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .background(.black)
    }

    var body: some View {
        VStack(spacing: 0) {
            videoSurface
            controls
            // Keep the movie name below the controls, never over the video.
            movieTitle
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        #if os(macOS)
        .background(MovieViewerWindowReader(window: $hostingWindow))
        #endif
        .task {
            if let initialTime { playback.seek(initialTime) }
            else if let stored = await getPosterFrameTime(from: url) { playback.seek(stored) }
        }
        #if os(iOS) || os(visionOS)
        .fullScreenCover(isPresented: $fullscreen) {
            VStack(spacing: 0) {
                videoSurface
                controls
                movieTitle
            }
            .background(.black)
            .overlay(alignment: .topTrailing) {
                Button("Close Fullscreen", systemImage: "arrow.down.right.and.arrow.up.left") {
                    fullscreen = false
                }
                .labelStyle(.iconOnly)
                .padding(12)
            }
        }
        #endif
        .onDisappear {
            if !fullscreen {
                stopFrameRepeat()
                playback.stopObserving()
            }
        }
    }

    @MainActor
    private func savePoster() async {
        guard let onPosterChanged, !working else { return }
        playback.pause()
        working = true
        defer { working = false }
        let selected = playback.seconds
        // The owner persists the selection first. A `false` response means
        // the selected timestamp is only a casting marker, not movie artwork.
        do {
            let writeEmbeddedPoster = try await onPosterChanged(selected)
            guard writeEmbeddedPoster else {
                // False is successful casting-only persistence, not failure.
                errorMessage = nil
                return
            }
            try await setPosterFrame(from: url, at: selected)
            errorMessage = nil
        } catch {
            // Failures must be visible in this window, not hidden behind it.
            errorMessage = "Could not save casting time: \(error.localizedDescription)"
        }
    }

}

#if os(macOS)
private struct MovieViewerWindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { window = view.window }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { window = view.window }
    }
}
#endif
#endif
