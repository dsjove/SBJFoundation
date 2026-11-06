import Foundation

//TODO: find a better place

public enum MacFlavor {
	case native
	case catalyst
	case iosOnMac

	public init?() {
#if targetEnvironment(macCatalyst)
		self = .catalyst
#elseif os(macOS)
		self = .native
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
