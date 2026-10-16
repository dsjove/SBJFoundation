#if os(iOS) || os(macOS)
@preconcurrency import AVFoundation
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
final class CameraModel: NSObject, Camera, CameraPreviewSource, @unchecked Sendable {
	private let simulatesFrontCameraFlash: Bool
	private let session = AVCaptureSession()

	private let sessionQueue = DispatchQueue(label: "camera.session.queue")
	private let photoOutput = AVCapturePhotoOutput()

	private var cameraPositionAvailability = CameraAvailability()
	private var selectedCameraPosition: CameraPosition = .back
	private var flashAvailability = FlashAvailability()
	private var selectedFlashMode: CameraFlashMode = .auto
	private var captureCompletion: (@MainActor @Sendable (Result<CapturedAttachment, Error>) -> Void)?

	private weak var previewLayer: AVCaptureVideoPreviewLayer?
	private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
	private var previewRotationObservation: NSKeyValueObservation?

	private(set) var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

	private(set) var rotationAngle: CGFloat = 0
	var isMirrored: Bool { cameraPosition == .front }

	// MARK: Construction

	init(simulatesFrontCameraFlash: Bool = false) {
		self.simulatesFrontCameraFlash = simulatesFrontCameraFlash
		super.init()
	}

	func start(
		initialFlashMode: CameraFlashMode,
		initialCameraPosition: CameraPosition
	) async throws {
		let status = try await ensureAuthorization()
		await MainActor.run {
			self.authorizationStatus = status
		}

		try await withCheckedThrowingContinuation { continuation in
			sessionQueue.async {
				do {
					try self.configureSessionIfNeeded(initialFlashMode, initialCameraPosition)

					if !self.session.isRunning {
						self.session.startRunning()
					}

					guard self.session.isRunning else {
						throw CameraError.sessionStartFailed
					}

					// Do not publish observable camera state until the session has
					// committed configuration and finished starting. Publishing from
					// inside beginConfiguration/commitConfiguration can cause SwiftUI
					// to create the preview layer while AVFoundation is still mutating
					// the same session (particularly fragile for Designed for iPad on Mac).
					self.refreshCameraProperties(initialFlashMode)

					self.sessionQueue.asyncAfter(deadline: .now() + 1.0) {
						self.turnTorchOnIfNeeded()
					}

					continuation.resume()
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	func poll() {
		_ = isAuthorized
		sessionQueue.async {
			self.applyOutputRotation()
			self.turnTorchOnIfNeeded()
		}
	}

	func stop() {
		sessionQueue.async {
			self.turnTorchOffIfNeeded()
			if self.session.isRunning {
				self.session.stopRunning()
			}
			self.previewRotationObservation = nil
			self.rotationCoordinator = nil
		}
	}
}

// MARK: Authorization

extension CameraModel {
	private func ensureAuthorization() async throws -> AVAuthorizationStatus {
		let current = AVCaptureDevice.authorizationStatus(for: .video)

		switch current {
		case .authorized:
			return .authorized
		case .notDetermined:
			let granted = await withCheckedContinuation { continuation in
				AVCaptureDevice.requestAccess(for: .video) { granted in
					continuation.resume(returning: granted)
				}
			}
			let updated = AVCaptureDevice.authorizationStatus(for: .video)
			if granted, updated == .authorized {
				return .authorized
			}
			throw CameraError.authorizationDenied
		case .denied:
			throw CameraError.authorizationDenied
		case .restricted:
			throw CameraError.authorizationRestricted
		@unknown default:
			throw CameraError.authorizationDenied
		}
	}

	var isAuthorized: Bool {
		let status = AVCaptureDevice.authorizationStatus(for: .video)
		Task { @MainActor in
			self.authorizationStatus = status
		}
		return status == .authorized
	}
}

// MARK: Session

extension CameraModel {
	private func configureSessionIfNeeded(_ forFlashMode: CameraFlashMode, _ forCameraPosition: CameraPosition) throws {
		if !session.inputs.isEmpty {
			return
		}

		session.beginConfiguration()
		defer { session.commitConfiguration() }

		session.sessionPreset = .photo

		let validatedPosition = validatedCameraPosition(forCameraPosition)
		let device = try getCameraDevice(for: validatedPosition)
		let input = try AVCaptureDeviceInput(device: device)

		guard session.canAddInput(input) else {
			throw CameraError.cannotAddCameraInput
		}
		session.addInput(input)

		guard session.canAddOutput(photoOutput) else {
			throw CameraError.cannotAddPhotoOutput
		}
		session.addOutput(photoOutput)
		let dimensions = device.activeFormat.supportedMaxPhotoDimensions
		if let largest = dimensions.max(by: {
			Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
		}) {
			photoOutput.maxPhotoDimensions = largest
		}

	}

	private func validatedCameraPosition(_ requestedPosition: CameraPosition) -> CameraPosition {
		let availability = CameraAvailability.discover()
		return requestedPosition.validated(by: availability)
	}

	private func getCameraDevice(for position: CameraPosition) throws -> AVCaptureDevice {
		guard let device = position.cameraDevice else {
			throw CameraError.noCameraAvailable
		}
		return device
	}

	@discardableResult
	private func refreshCameraProperties(_ requestedFlashMode: CameraFlashMode) -> CameraFlashMode {
		let cameraAvailability = CameraAvailability.discover()
		let currentDevice = currentDeviceInput()?.device
		let currentPosition = CameraPosition(native: currentDevice?.position)
		let flashAvailability = FlashAvailability(
			device: currentDevice,
			photoOutput: photoOutput,
			simulatesFrontCameraFlash: simulatesFrontCameraFlash
		)
		let validatedMode = requestedFlashMode.validated(by: flashAvailability)

		applyTorchModeIfNeeded(validatedMode, on: currentDevice)

		DispatchQueue.main.async {
			self.cameraPositionAvailability = cameraAvailability
			self.selectedCameraPosition = currentPosition
			self.flashAvailability = flashAvailability
			self.selectedFlashMode = validatedMode
		}

		return validatedMode
	}

	private func currentDeviceInput() -> AVCaptureDeviceInput? {
		session.inputs.compactMap { $0 as? AVCaptureDeviceInput }.first
	}

	private var currentInputIsFront: Bool {
		currentDeviceInput()?.device.position == .front
	}
}

// MARK: Rotation Coordinator

extension CameraModel {
	func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
		// SwiftUI may call updateUIView/updateNSView many times as observed
		// camera state changes. Reassigning AVCaptureVideoPreviewLayer.session
		// during an AttributeGraph update is both unnecessary and, on an iOS
		// app running on Mac, can trigger an AttributeGraph/AVFoundation cycle.
		guard previewLayer !== layer || layer.session !== session else { return }

		previewLayer = layer
		layer.videoGravity = .resizeAspectFill
		if layer.session !== session {
			layer.session = session
		}

		sessionQueue.async {
			self.installRotationCoordinator()
			self.applyOutputRotation()
		}
	}

	func detachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
		guard previewLayer === layer else { return }

		// Do not reassign layer.session while the capture session may be
		// stopping. Releasing the representable releases the preview layer;
		// clearing our weak reference is sufficient.
		previewLayer = nil

		sessionQueue.async {
			self.previewRotationObservation = nil
			self.rotationCoordinator = nil
		}
	}

	private func installRotationCoordinator() {
		previewRotationObservation = nil

		guard let device = currentDeviceInput()?.device else {
			rotationCoordinator = nil
			Task { @MainActor in
				self.rotationAngle = 0
			}
			return
		}

		let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
		rotationCoordinator = coordinator

		let initialAngle = coordinator.videoRotationAngleForHorizonLevelPreview
		applyPreviewRotation(initialAngle)
		Task { @MainActor in
			self.rotationAngle = initialAngle
		}

		previewRotationObservation = coordinator.observe(
			\.videoRotationAngleForHorizonLevelPreview,
			options: [.initial, .new]
		) { [weak self] coordinator, _ in
			guard let model = self else { return }
			let angle = coordinator.videoRotationAngleForHorizonLevelPreview
			model.sessionQueue.async { [model] in
				model.applyPreviewRotation(angle)
				model.applyOutputRotation()
				Task { @MainActor in
					model.rotationAngle = angle
				}
			}
		}
	}

	private func applyPreviewRotation(_ previewAngle: CGFloat) {
		guard let connection = previewLayer?.connection else { return }

		if connection.isVideoRotationAngleSupported(previewAngle) {
			connection.videoRotationAngle = previewAngle
		}

		applyPreviewMirroring(isFront: currentInputIsFront)
	}

	private func applyPreviewMirroring(isFront: Bool) {
		guard let connection = previewLayer?.connection else { return }
		guard connection.isVideoMirroringSupported else { return }

		// AVFoundation can automatically change preview mirroring when the session
		// input changes. Disable that behavior and set the destination state before
		// committing an input swap so the first frame from the new camera is already
		// presented with the correct mirroring.
		connection.automaticallyAdjustsVideoMirroring = false
		connection.isVideoMirrored = isFront
	}

	private func applyOutputRotation() {
		guard
			let coordinator = rotationCoordinator,
			let connection = photoOutput.connection(with: .video)
		else {
			return
		}

		// RotationCoordinator provides a distinct still-capture angle. Use it on
		// every supported platform, including Mac Catalyst and iOS apps on Mac.
		// The photo output records this orientation in the captured image metadata.
		let captureAngle = coordinator.videoRotationAngleForHorizonLevelCapture

		if connection.isVideoRotationAngleSupported(captureAngle) {
			connection.videoRotationAngle = captureAngle
		}

		if connection.isVideoMirroringSupported {
			connection.automaticallyAdjustsVideoMirroring = false
			connection.isVideoMirrored = currentInputIsFront
		}
	}
}

// MARK: Camera Position

extension CameraModel {
	var hasCamera: Bool {
		cameraPositionAvailability.hasAny
	}

	var hasCameraOptions: Bool {
		cameraPositionAvailability.hasOptions
	}

	var cameraPosition: CameraPosition {
		selectedCameraPosition
	}

	func nextCameraPosition(requesting: CameraPosition? = nil) async throws -> CameraPosition {
		let proposed = requesting?.validated(by: cameraPositionAvailability) ?? selectedCameraPosition.next(by: cameraPositionAvailability)
		return try await setCameraPosition(proposed)
	}

	private func setCameraPosition(_ requested: CameraPosition) async throws -> CameraPosition {
		try await withCheckedThrowingContinuation { continuation in
			sessionQueue.async {
				do {
					let applied = try self.applyValidatedCameraPosition(requested)
					self.installRotationCoordinator()
					self.applyOutputRotation()
					continuation.resume(returning: applied)
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	@discardableResult
	private func applyValidatedCameraPosition(_ requested: CameraPosition) throws -> CameraPosition {
		let validated = validatedCameraPosition(requested)

		guard let currentInput = currentDeviceInput() else {
			try configureSessionIfNeeded(selectedFlashMode, validated)
			refreshCameraProperties(selectedFlashMode)
			return CameraPosition(native: currentDeviceInput()?.device.position)
		}

		if currentInput.device.position == validated.native {
			refreshCameraProperties(selectedFlashMode)
			return validated
		}

		turnTorchOffIfNeeded()

		let newDevice = try getCameraDevice(for: validated)
		let newInput = try AVCaptureDeviceInput(device: newDevice)

		session.beginConfiguration()
		defer { session.commitConfiguration() }

		session.removeInput(currentInput)

		guard session.canAddInput(newInput) else {
			session.addInput(currentInput)
			throw CameraError.cannotAddCameraInput
		}

		session.addInput(newInput)

		// Adding a new input can recreate/reset the preview connection and its
		// automatic mirroring state. Apply the destination camera's mirroring only
		// after the new input exists, but still before commitConfiguration(). That
		// way the first frame released from the new camera is already presented in
		// its final mirror state instead of visibly flipping a moment later when the
		// new rotation coordinator is installed.
		applyPreviewMirroring(isFront: validated == .front)

		refreshCameraProperties(selectedFlashMode)
		return validated
	}
}

// MARK: Flash

extension CameraModel {
	var hasFlash: Bool {
		flashAvailability.hasFlash
	}

	var hasTorch: Bool {
		flashAvailability.hasTorch
	}

	var shouldUseSimulatedFlash: Bool {
		guard simulatesFrontCameraFlash, selectedCameraPosition == .front else { return false }
		switch selectedFlashMode {
		case .on:
			return true
		case .auto:
			return photoOutput.isFlashScene
		case .off, .torch:
			return false
		}
	}

	var flashMode: CameraFlashMode {
		selectedFlashMode
	}

	func nextFlashMode(requesting: CameraFlashMode? = nil) async throws -> CameraFlashMode {
		let proposed = requesting?.validated(by: flashAvailability) ?? selectedFlashMode.next(by: flashAvailability)
		return try await setFlashMode(proposed)
	}

	private func setFlashMode(_ requested: CameraFlashMode) async throws -> CameraFlashMode {
		try await withCheckedThrowingContinuation { continuation in
			sessionQueue.async {
				let applied = self.refreshCameraProperties(requested)
				continuation.resume(returning: applied)
			}
		}
	}

	private func applyTorchModeIfNeeded(_ mode: CameraFlashMode, on device: AVCaptureDevice?) {
		guard let device, device.hasTorch else { return }
		switch mode {
		case .torch:
			do {
				try device.lockForConfiguration()
				defer { device.unlockForConfiguration() }
				if device.isTorchModeSupported(.on) {
					try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
				}
			} catch {
			}
		default:
			do {
				try device.lockForConfiguration()
				defer { device.unlockForConfiguration() }
				if device.isTorchActive || device.torchMode != .off {
					device.torchMode = .off
				}
			} catch {
			}
		}
	}

	private func turnTorchOnIfNeeded() {
		guard let device = currentDeviceInput()?.device else { return }
		if selectedFlashMode == .torch {
			applyTorchModeIfNeeded(.torch, on: device)
		}
	}

	private func turnTorchOffIfNeeded() {
		guard let device = currentDeviceInput()?.device else { return }
		applyTorchModeIfNeeded(.off, on: device)
	}
}

// MARK: Capture

extension CameraModel: AVCapturePhotoCaptureDelegate {
	func capture(completion: @escaping @MainActor @Sendable (Result<CapturedAttachment, Error>) -> Void) {
		sessionQueue.async {
			if self.captureCompletion != nil {
				Task { @MainActor in
					completion(.failure(CameraError.captureAlreadyInProgress))
				}
				return
			}

			self.captureCompletion = completion
			self.applyOutputRotation()

			let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
			settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions

			if let native = self.selectedFlashMode.nativeFlashMode,
			   self.photoOutput.supportedFlashModes.contains(native) {
				settings.flashMode = native
			}

			// Keep AVCapturePhotoOutput capture requests serialized with all other
			// session/output work. There is no UI work here that requires MainActor,
			// and hopping queues between configuring settings and submitting them can
			// race session/input changes (including flash capability changes).
			self.photoOutput.capturePhoto(with: settings, delegate: self)
		}
	}

	func photoOutput(
		_ output: AVCapturePhotoOutput,
		didFinishProcessingPhoto photo: AVCapturePhoto,
		error: Error?
	) {
		sessionQueue.async {
			if let error {
				self.finishCapture(.failure(error))
				return
			}

			guard let originalData = photo.fileDataRepresentation() else {
				self.finishCapture(.failure(CameraError.jpegDataCreationFailed))
				return
			}

			self.finishCapture(
				.success(
					CapturedAttachment(
						blob: originalData,
						utiType: UTType.jpeg.identifier
					)
				)
			)
		}
	}

	private func finishCapture(_ result: Result<CapturedAttachment, Error>) {
		let completion = self.captureCompletion
		self.captureCompletion = nil

		Task { @MainActor in
			completion?(result)
		}
	}
}

#endif
