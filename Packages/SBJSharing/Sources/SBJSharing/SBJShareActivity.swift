#if canImport(UIKit)
import UIKit
public typealias SBJShareActivity = UIActivity
#elseif canImport(AppKit)
import AppKit
public typealias SBJShareActivity = NSSharingService
#endif
