#if os(iOS)
import Foundation
import Photos
import SBJShared

/// A named encoded image resource that can be passed to image destinations
/// without losing its content type or filename.
public protocol PhotoImport: Sendable {
	var resourceContent: SBJResourceContent { get }
	var filename: String { get }
}

public enum PhotoSaveResult: Sendable, CustomStringConvertible {
	case saved
	case denied
	case failed(String?)

	func accumulate(with result: PhotoSaveResult) -> PhotoSaveResult {
		switch (self, result) {
		case (.failed(let error), _):
			.failed(error)
		case (_, .failed(let error)):
			.failed(error)
		case (.denied, _), (_, .denied):
			.denied
		default:
			.saved
		}
	}

	public var description: String {
		switch self {
		case .saved:
			"Photos saved to library."
		case .denied:
			"Photo library access was denied."
		case .failed(let error):
			if let error, !error.isEmpty {
				"Photo save failed: \(error)"
			} else {
				"Photo save failed."
			}
		}
	}
}

/// Add-only access to the user's photo library.
///
/// Batch saves deliberately use independent tasks. Photos can occasionally take
/// much longer to complete one change request than another, and a slow save
/// should not serialize the rest of the batch.
public enum PhotoLibrary {
	public static func savePhoto(photo: any PhotoImport) async -> PhotoSaveResult {
		await savePhoto(photos: [photo])
	}

	public static func savePhoto(photos: [any PhotoImport]) async -> PhotoSaveResult {
		guard !photos.isEmpty else { return .saved }

		return await withTaskGroup(of: PhotoSaveResult.self) { group in
			for photo in photos {
				group.addTask {
					await savePhoto(content: photo.resourceContent, filename: photo.filename)
				}
			}

			var accumulated = PhotoSaveResult.saved
			for await result in group {
				accumulated = accumulated.accumulate(with: result)
			}
			return accumulated
		}
	}

	public static var isAuthorized: Bool? {
		let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
		guard status != .notDetermined else { return nil }
		return status == .authorized || status == .limited
	}

	public static func savePhoto(content: SBJResourceContent, filename: String) async -> PhotoSaveResult {
		let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

		switch status {
		case .authorized, .limited:
			return await performSave(content: content, filename: filename)
		case .notDetermined:
			let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
			guard newStatus == .authorized || newStatus == .limited else {
				return .denied
			}
			return await performSave(content: content, filename: filename)
		default:
			return .denied
		}
	}

	private static func performSave(content: SBJResourceContent, filename: String) async -> PhotoSaveResult {
		let resolvedFilename = filename.sanitizedFilename(contentType: content.contentType)
		return await withCheckedContinuation { continuation in
			PHPhotoLibrary.shared().performChanges({
				let request = PHAssetCreationRequest.forAsset()
				let options = PHAssetResourceCreationOptions()
				options.originalFilename = resolvedFilename
				request.addResource(with: .photo, data: content.data, options: options)
			}) { success, error in
				if success {
					continuation.resume(returning: .saved)
				} else {
					continuation.resume(returning: .failed(error?.localizedDescription))
				}
			}
		}
	}
}
#endif
