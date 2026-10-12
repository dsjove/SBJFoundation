import SwiftUI

#if os(iOS) || os(macOS)
import AVFoundation
#endif

/// A cross-platform SwiftUI still-camera view.
///
/// On iOS, iPadOS, Mac Catalyst, and macOS it uses the package's single
/// AVFoundation capture implementation. On Apple platforms without ordinary
/// app camera capture it renders a standard unavailable view instead of making
/// callers conditionalize their SwiftUI hierarchy.
@MainActor
public struct CameraCaptureView: View {
    public typealias Completion = @MainActor (CapturedAttachment?) -> Void

    public static var isAvailable: Bool {
        #if os(iOS) || os(macOS)
        AVCaptureDevice.default(for: .video) != nil
        #else
        false
        #endif
    }

    private let initialFlashMode: CameraFlashMode
    private let initialCameraPosition: CameraPosition
    private let completion: Completion

    @Environment(\.dismiss) private var dismiss

    public init(
        initialFlashMode: CameraFlashMode = .auto,
        initialCameraPosition: CameraPosition = .back,
        completion: @escaping Completion
    ) {
        self.initialFlashMode = initialFlashMode
        self.initialCameraPosition = initialCameraPosition
        self.completion = completion
    }

    public var body: some View {
        #if os(iOS) || os(macOS)
        CameraCaptureAvailableView(
            initialFlashMode: initialFlashMode,
            initialCameraPosition: initialCameraPosition
        ) { attachment in
            completion(attachment)
            dismiss()
        }
        #else
        ContentUnavailableView(
            "Camera Unavailable",
            systemImage: "camera.slash",
            description: Text("Camera capture is not available on this platform.")
        )
        #endif
    }
}

#if os(iOS) || os(macOS)
@MainActor
private struct CameraCaptureAvailableView: View {
    let initialFlashMode: CameraFlashMode
    let initialCameraPosition: CameraPosition
    let completion: CameraCaptureView.Completion

    @State private var camera = CameraModel()
    @State private var isStarting = true
    @State private var isCapturing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isAuthorized && camera.hasCamera {
                CameraPreview(camera: camera)
                    .ignoresSafeArea()
            }

            controls

            if isStarting {
                ProgressView("Starting camera…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else if let errorMessage {
                ContentUnavailableView(
                    "Camera Unavailable",
                    systemImage: "camera.slash",
                    description: Text(errorMessage)
                )
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task {
            await start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var controls: some View {
        VStack {
            HStack(spacing: 16) {
                Button {
                    completion(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("Cancel")

                Spacer()

                if camera.hasFlash {
                    Button {
                        Task { await cycleFlash() }
                    } label: {
                        Image(systemName: flashSymbol)
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Change flash mode")
                }

                if camera.hasCameraOptions {
                    Button {
                        Task { await switchCamera() }
                    } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .accessibilityLabel("Switch camera")
                }
            }
            .padding()

            Spacer()

            if errorMessage == nil && camera.isAuthorized && camera.hasCamera {
                Button {
                    capture()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill(.white)
                            .frame(width: 62, height: 62)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isStarting || isCapturing)
                .opacity((isStarting || isCapturing) ? 0.45 : 1)
                .accessibilityLabel("Take photo")
                .padding(.bottom, 28)
            }
        }
    }

    private var flashSymbol: String {
        switch camera.flashMode {
        case .off: "bolt.slash.fill"
        case .on: "bolt.fill"
        case .auto: "bolt.badge.a.fill"
        case .torch: "flashlight.on.fill"
        }
    }

    private func start() async {
        isStarting = true
        errorMessage = nil
        do {
            try await camera.start(
                initialFlashMode: initialFlashMode,
                initialCameraPosition: initialCameraPosition
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isStarting = false
    }

    private func capture() {
        guard !isCapturing else { return }
        isCapturing = true
        camera.capture { result in
            isCapturing = false
            switch result {
            case .success(let attachment):
                completion(attachment)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func switchCamera() async {
        do {
            _ = try await camera.nextCameraPosition()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cycleFlash() async {
        do {
            _ = try await camera.nextFlashMode()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
