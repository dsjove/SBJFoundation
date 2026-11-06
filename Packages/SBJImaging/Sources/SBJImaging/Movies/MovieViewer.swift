#if os(macOS) || os(iOS) || os(visionOS)
import SwiftUI
import Observation
import AVFoundation
import AVKit
import CoreImage
import SBJLocalization
import SBJDataDefinition
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Thread-safe settings snapshot for AVFoundation's asynchronous render callback.
private final class PlaybackEnhancementBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value = PhotoColorAdjustments()
    func set(_ next: PhotoColorAdjustments) {
        lock.lock(); defer { lock.unlock() }
        value = next
    }
    func get() -> PhotoColorAdjustments {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}

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
    private let enhancementBox = PlaybackEnhancementBox()
    private var hasEnhancementComposition = false

    /// Leave AVPlayer on its native decoding/rendering path when no filters
    /// are active. Attach a Core Image composition only while required.
    func updateEnhancements(_ changes: PhotoColorAdjustments, enabled: Bool) {
        let settings = enabled ? changes : PhotoColorAdjustments()
        enhancementBox.set(settings)
        guard let item = player.currentItem else { return }
        let needsProcessing = !settings.isNeutral
        guard needsProcessing != hasEnhancementComposition else { return }
        if needsProcessing {
            let box = enhancementBox
            item.videoComposition = AVVideoComposition(
                asset: item.asset,
                applyingCIFiltersWithHandler: { request in
                    let settings = box.get()
                    let filtered = settings.applying(to: request.sourceImage)
                    request.finish(
                        with: filtered.cropped(to: request.sourceImage.extent),
                        context: nil
                    )
                }
            )
        } else {
            item.videoComposition = nil
        }
        hasEnhancementComposition = needsProcessing
    }

    init(url: URL) {
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
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
    @State private var enhancements = PhotoColorAdjustments()
    @State private var enhancementsEnabled = true
    @State private var showingEnhancements = false
    // AVPlayer does not promise to redraw an already paused frame when only
    // its video-composition filter parameters change. Render that frame here.
    @State private var pausedSourceFrame: CGImage?
    @State private var pausedPreviewFrame: CGImage?
    @State private var pausedFrameTask: Task<Void, Never>?
    @State private var pausedFrameTime: Double?
    private let pausedFrameContext = CIContext()
    @State private var errorMessage: String?
    @State private var enhancementApplyTask: Task<Void, Never>?
    @State private var enhancementThrottleActive = false
    @State private var pendingEnhancementState: EnhancementState?
    private let enhancementThrottleInterval: Duration = .milliseconds(80)
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


    private struct EnhancementState: Equatable {
        let adjustments: PhotoColorAdjustments
        let isEnabled: Bool
    }

    private func applyEnhancementState(_ state: EnhancementState) {
        playback.updateEnhancements(state.adjustments, enabled: state.isEnabled)
        refreshPausedFrame()
        redrawPausedFrame()
    }

    /// Leading + trailing throttle: the first slider change applies
    /// immediately, later changes within the window are coalesced to the
    /// latest value, and the final value is always delivered.
    private func scheduleEnhancementApply() {
        let current = EnhancementState(
            adjustments: enhancements,
            isEnabled: enhancementsEnabled
        )

        guard enhancementThrottleActive else {
            enhancementThrottleActive = true
            pendingEnhancementState = nil
            applyEnhancementState(current)
            enhancementApplyTask?.cancel()
            enhancementApplyTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: enhancementThrottleInterval)
                    guard !Task.isCancelled else { break }
                    if let pendingEnhancementState {
                        let pending = pendingEnhancementState
                        self.pendingEnhancementState = nil
                        applyEnhancementState(pending)
                    } else {
                        enhancementThrottleActive = false
                        enhancementApplyTask = nil
                        break
                    }
                }
            }
            return
        }

        pendingEnhancementState = current
    }

    private func stopEnhancementApplyTask() {
        enhancementApplyTask?.cancel()
        enhancementApplyTask = nil
        enhancementThrottleActive = false
        pendingEnhancementState = nil
    }

    private var videoSurface: some View {
        ZStack {
            NativeVideoSurface(playback: playback)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !playback.isPlaying, enhancementsEnabled,
               !enhancements.isNeutral, let pausedPreviewFrame {
                Image(decorative: pausedPreviewFrame, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
        // AVKit and the still-frame overlay both preserve the source aspect.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Fetch only when the selected frame changes; slider changes reuse the
    /// cached source CGImage and immediately redraw it with the new recipe.
    private func refreshPausedFrame() {
        guard !playback.isPlaying, enhancementsEnabled,
              !enhancements.isNeutral else {
            pausedFrameTask?.cancel()
            pausedFrameTask = nil
            pausedSourceFrame = nil
            pausedPreviewFrame = nil
            pausedFrameTime = nil
            return
        }
        let time = playback.seconds
        guard time.isFinite, time >= 0 else { return }
        if let previous = pausedFrameTime, abs(previous - time) < 0.005,
           pausedSourceFrame != nil { return }
        pausedFrameTask?.cancel()
        pausedFrameTime = time
        pausedSourceFrame = nil
        pausedPreviewFrame = nil
        pausedFrameTask = Task { @MainActor in
            // Limit decoding to display resolution. The saved poster still
            // uses the original full-resolution frame-generation path.
            let frame = await getPosterFrame(from: url, at: time,
                                             fitting: CGSize(width: 1920, height: 1080))
            guard !Task.isCancelled, !playback.isPlaying,
                  abs(playback.seconds - time) < 0.05 else { return }
            pausedSourceFrame = frame
            redrawPausedFrame()
        }
    }

    private func redrawPausedFrame() {
        guard enhancementsEnabled, !enhancements.isNeutral else {
            pausedPreviewFrame = nil
            return
        }
        guard let pausedSourceFrame, !playback.isPlaying else { return }
        pausedPreviewFrame = enhancements.applying(
            to: pausedSourceFrame,
            context: pausedFrameContext
        ) ?? pausedSourceFrame
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
            Button("Enhancements", systemImage: "slider.horizontal.3") {
                showingEnhancements.toggle()
            }
                .labelStyle(.iconOnly)
                .popover(isPresented: $showingEnhancements) {
                    ImageEnhancementControls(
                        adjustments: $enhancements,
                        isEnabled: $enhancementsEnabled
                    )
                    // Explicit opaque surface: macOS popover vibrancy otherwise
                    // makes the text nearly white over a pale translucent view.
                    .environment(\.colorScheme, .light)
                    .foregroundStyle(.black)
                    .background(Color.white)
                }
                .help("Image enhancements")
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
        .disabled(working)
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

    @ViewBuilder
    private var savingIndicator: some View {
        if working {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Saving poster frame…")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.black)
            .accessibilityElement(children: .combine)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            videoSurface
            controls
            savingIndicator
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
        .onChange(of: enhancements) { _, _ in
            scheduleEnhancementApply()
        }
        .onChange(of: enhancementsEnabled) { _, _ in
            scheduleEnhancementApply()
        }
        .onChange(of: playback.isPlaying) { _, _ in refreshPausedFrame() }
        .onChange(of: playback.seconds) { _, _ in
            if !playback.isPlaying { refreshPausedFrame() }
        }
        .task {
            if let initialTime { playback.seek(initialTime) }
            refreshPausedFrame()
        }
        #if os(iOS) || os(visionOS)
        .fullScreenCover(isPresented: $fullscreen) {
            VStack(spacing: 0) {
                videoSurface
                controls
                savingIndicator
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
                stopEnhancementApplyTask()
                pausedFrameTask?.cancel()
                pausedFrameTask = nil
                pausedPreviewFrame = nil
                pausedSourceFrame = nil
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
            // The unmodified path extracts and embeds the frame within the setter.
            // With edits, render a full-resolution frame and pass the adjusted
            // image to the existing image-based setter (no scaled preview).
            if enhancementsEnabled && !enhancements.isNeutral {
                guard let source = await getPosterFrame(from: url, at: selected) else {
                    throw NSError(
                        domain: "SBJImaging.MovieViewer", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Could not extract the selected movie frame."]
                    )
                }
                let adjusted = enhancements.applying(to: source) ?? source
                try await setPosterFrame(from: url, image: adjusted)
            } else {
                try await setPosterFrame(from: url, at: selected)
            }
            errorMessage = nil
        } catch {
            // Failures must be visible in this window, not hidden behind it.
            errorMessage = "Could not save poster frame: \(error.localizedDescription)"
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
