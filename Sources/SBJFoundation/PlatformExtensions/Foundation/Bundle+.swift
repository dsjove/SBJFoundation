import SBJUIVocabulary
import UIKit

import SBJDataDefinition
public extension Bundle {
	var displayName: String? {
		self.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
		?? self.object(forInfoDictionaryKey: "CFBundleName") as? String
	}

	var version: String? {
		self.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
	}

	var build: String? {
		self.object(forInfoDictionaryKey: "CFBundleVersion") as? String
	}

	var fullVersion: String? {
		if let version {
			if let build {
				return "\(version) (\(build))"
			}
			return version
		} else if let build {
			return build
		}
		return nil
	}

	/// The application's icon as an image suitable for displaying in-app.
	///
	/// `AppIconDisplay` is a normal image set in the asset catalog containing
	/// the flattened artwork used when the app icon needs to be shown in-app.
	var icon: UIImage? {
#if os(watchOS)
		if let displayIcon = UIImage(named: "AppIconDisplay") {
			return displayIcon
		}
#else
		if let displayIcon = UIImage(named: "AppIconDisplay", in: self, compatibleWith: nil) {
			return displayIcon
		}
#endif
		func image(named name: String) -> UIImage? {
#if os(watchOS)
			UIImage(named: name)
			?? ImageReference.resource(name, bundle: self).image
#else
			UIImage(named: name, in: self, compatibleWith: nil)
			?? ImageReference.resource(name, bundle: self).image
#endif
		}

		if let iconName = object(forInfoDictionaryKey: "CFBundleIconName") as? String {
			if let image = image(named: iconName) { return image }
			if let url = url(forResource: iconName, withExtension: "icns"),
			   let image = UIImage(contentsOfFile: url.path) {
				return image
			}
		}

		let dictionaries = ["CFBundleIcons", "CFBundleIcons~ipad"]
		for key in dictionaries {
			guard let icons = infoDictionary?[key] as? [String: Any],
			      let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any]
			else { continue }
			if let iconName = primaryIcon["CFBundleIconName"] as? String,
			   let image = image(named: iconName) {
				return image
			}

			if let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] {
				for iconFile in iconFiles.reversed() {
					if let image = image(named: iconFile) { return image }
				}
			}
		}

		return nil
	}
}
