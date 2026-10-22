import PhotosUI
import SwiftUI
import UIKit
import SBJCamera
import SBJDataDefinition
import SBJUIVocabulary

public struct PhotoMenuOptions: OptionSet, Sendable {
	public let rawValue: Int

	// Importing
	public static let photos = PhotoMenuOptions(rawValue: 1 << 0)
	public static let camera = PhotoMenuOptions(rawValue: 1 << 1)
	public static let files = PhotoMenuOptions(rawValue: 1 << 2)
	public static let paste = PhotoMenuOptions(rawValue: 1 << 3)
	// Editing
	public static let edit = PhotoMenuOptions(rawValue: 1 << 4)
	public static let clear = PhotoMenuOptions(rawValue: 1 << 5)
	// Viewing
	public static let view = PhotoMenuOptions(rawValue: 1 << 6)
	public static let share = PhotoMenuOptions(rawValue: 1 << 7)

	public static let none: PhotoMenuOptions = []

	public static let imports: PhotoMenuOptions = [.photos, .camera, .files, .paste]
	public static let edits: PhotoMenuOptions = [.edit, .clear]
	public static let reading: PhotoMenuOptions = [.view, .share]
	public static let all: PhotoMenuOptions = [imports, edits, reading]
	public static let modify: PhotoMenuOptions = [imports, edits]

	public init(rawValue: Int) {
		self.rawValue = rawValue
	}

	public static var canShowPhotos: Bool {
#if os(iOS) || os(visionOS)
		if #available(iOS 14, visionOS 1, *) {
			return true
		}
		return false
#elseif os(macOS)
		if #available(macOS 12, *) {
			return true
		}
		return false
#else
		return false
#endif
	}

	@MainActor
	public static var canShowCamera: Bool {
#if os(watchOS)
        false
#else
        CameraView.isAvailable
#endif
    }

	public static var canShowFiles: Bool {
#if os(iOS) || os(macOS) || os(visionOS)
		if #available(iOS 14, macOS 11, visionOS 1, *) {
			return true
		}
		return false
#else
		return false
#endif
	}
}
