import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
    /// Prefer the explicit AppIconDisplay asset, since compiled app icons are not
    /// always directly addressable as ordinary asset catalog images.
    var icon: SBJImage? {
        #if canImport(UIKit)
        #if os(watchOS)
        if let image = UIImage(named: "AppIconDisplay") { return image }
        #else
        if let image = UIImage(named: "AppIconDisplay", in: self, compatibleWith: nil) { return image }
        #endif
        #elseif canImport(AppKit)
        if let image = NSImage(named: NSImage.Name("AppIconDisplay")) { return image }
        #endif

        func image(named name: String) -> SBJImage? {
            #if canImport(UIKit)
            #if os(watchOS)
            return UIImage(named: name)
                ?? SBJSymbol.bundleImage(name: name, bundle: self).nativeImage
            #else
            return UIImage(named: name, in: self, compatibleWith: nil)
                ?? SBJSymbol.bundleImage(name: name, bundle: self).nativeImage
            #endif
            #elseif canImport(AppKit)
            return (self == .main ? NSImage(named: NSImage.Name(name)) : nil)
                ?? SBJSymbol.bundleImage(name: name, bundle: self).nativeImage
            #endif
        }

        if let iconName = object(forInfoDictionaryKey: "CFBundleIconName") as? String {
            if let image = image(named: iconName) { return image }
            if let url = url(forResource: iconName, withExtension: "icns"),
               let image = SBJImage(contentsOfFile: url.path) { return image }
        }

        #if canImport(AppKit)
        // macOS traditionally records an .icns file in CFBundleIconFile.
        if let iconFile = object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
            let name = (iconFile as NSString).deletingPathExtension
            if let image = image(named: name) { return image }
            if let url = url(forResource: name, withExtension: "icns"),
               let image = NSImage(contentsOf: url) { return image }
        }
        #endif

        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            guard let icons = infoDictionary?[key] as? [String: Any],
                  let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] else { continue }
            if let name = primary["CFBundleIconName"] as? String,
               let image = image(named: name) { return image }
            if let files = primary["CFBundleIconFiles"] as? [String] {
                for file in files.reversed() {
                    if let image = image(named: file) { return image }
                }
            }
        }
        return nil
    }
}
