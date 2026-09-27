import Foundation

public enum MacFlavor {
	case native
	case catalyst
	case iosOnMac

	public init?() {
#if os(macOS)
		self = .native
#elseif targetEnvironment(macCatalyst)
		self = .catalyst
#else
		let info = ProcessInfo.processInfo
		if info.isMacCatalystApp {
			self = .catalyst
		} else if info.isiOSAppOnMac {
			self = .iosOnMac
		} else {
			return nil
		}
#endif
	}
}

public extension ProcessInfo {
	static var isAnyMac: Bool {
		MacFlavor() != nil
	}
}
