#if !os(watchOS) && !os(tvOS) && canImport(UIKit)
import UIKit
public typealias SBJShareActivity = UIActivity
#elseif os(macOS) && canImport(AppKit)
import AppKit
public typealias SBJShareActivity = NSSharingService
#endif
