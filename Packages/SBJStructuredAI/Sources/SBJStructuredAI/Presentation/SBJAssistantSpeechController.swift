import Foundation
import Observation

#if canImport(Speech) && canImport(AVFoundation) && !os(watchOS) && !os(tvOS)
import Speech
import AVFoundation

/// Speech is an input/output adapter only. A recognized transcript becomes editable
/// draft text; it never invokes semantic tools or approves a proposal automatically.
@MainActor
@Observable
public final class SBJAssistantSpeechController {
	public private(set) var isListening = false
	public private(set) var transcript = ""
	public private(set) var errorMessage: String?
	public var speaksResponses = false {
		didSet { if !speaksResponses { synthesizer.stopSpeaking(at: .immediate) } }
	}

	public init() {}

	private let synthesizer = AVSpeechSynthesizer()
	private var engine: AVAudioEngine?
	private var request: SFSpeechAudioBufferRecognitionRequest?
	private var recognitionTask: SFSpeechRecognitionTask?
	private var generation = 0

	public func start() async {
		guard !isListening else { return }
		errorMessage = nil
		generation += 1
		let currentGeneration = generation
		let permission = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
			SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
		}
		guard currentGeneration == generation else { return }
		guard permission == .authorized else {
			errorMessage = "Speech recognition permission was denied."
			return
		}
		let audioPermission = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
			AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
		}
		guard currentGeneration == generation else { return }
		guard audioPermission else {
			errorMessage = "Microphone permission was denied."
			return
		}
		guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
			errorMessage = "Speech recognition is unavailable."
			return
		}
		transcript = ""
		synthesizer.stopSpeaking(at: .immediate)
		let engine = AVAudioEngine()
		let request = SFSpeechAudioBufferRecognitionRequest()
		request.shouldReportPartialResults = true
		do {
			let input = engine.inputNode
			let format = input.outputFormat(forBus: 0)
			input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
				request.append(buffer)
			}
			engine.prepare()
			try engine.start()
			self.engine = engine
			self.request = request
			isListening = true
			recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
				Task { @MainActor [weak self] in
					guard let self, self.generation == currentGeneration else { return }
					if let result { self.transcript = result.bestTranscription.formattedString }
					if let error {
						self.errorMessage = error.localizedDescription
						self.stop()
					} else if result?.isFinal == true {
						self.stop()
					}
				}
			}
		} catch {
			engine.inputNode.removeTap(onBus: 0)
			errorMessage = error.localizedDescription
			stop()
		}
	}

	public func stop() {
		generation += 1
		engine?.stop()
		engine?.inputNode.removeTap(onBus: 0)
		request?.endAudio()
		recognitionTask?.cancel()
		recognitionTask = nil
		request = nil
		engine = nil
		isListening = false
	}

	public func reset() {
		stop()
		synthesizer.stopSpeaking(at: .immediate)
		transcript = ""
		errorMessage = nil
	}

	public func speak(_ text: String) {
		guard speaksResponses, !text.isEmpty, !isListening else { return }
		synthesizer.stopSpeaking(at: .immediate)
		synthesizer.speak(AVSpeechUtterance(string: text))
	}
}

#else

@MainActor
@Observable
public final class SBJAssistantSpeechController {
	public let isListening = false
	public let transcript = ""
	public let errorMessage: String? = "Unsupported"
	public var speaksResponses = false

	public init() {}
	public func start() async {}
	public func reset() {}
	public func stop() {}
	public func speak(_: String) {}
}

#endif
