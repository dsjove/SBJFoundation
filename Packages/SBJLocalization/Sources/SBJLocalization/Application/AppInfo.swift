import UIKit

public enum AppInfo {
//These need to be localized
	public static let companyName: String = "Software by Jove"
	public static let supportEmail: String = "softwarebyjove@gmail.com"
	public static let supportURL: String = "https://github.com/dsjove/SoftwareByJove"
	public static var privacyPolicyURL: String { supportURL }

	public static var displayName: String {
		Bundle.main.displayName ?? "Unknown App"
	}

	public static var version: String {
		Bundle.main.version ?? "Unknown"
	}

	public static var build: String {
		Bundle.main.build ?? "Unknown"
	}

	public static var fullVersion: String {
		Bundle.main.fullVersion ?? "Unknown"
	}

	public static var bundleIdentifier: String {
		Bundle.main.bundleIdentifier ?? "Unknown"
	}

	public static var icon: UIImage? {
		Bundle.main.icon
	}
}
