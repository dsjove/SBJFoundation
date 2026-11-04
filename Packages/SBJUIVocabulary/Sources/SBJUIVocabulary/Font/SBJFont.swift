#if canImport(UIKit)
import UIKit
public typealias SBJFont = UIFont
#elseif canImport(AppKit)
import AppKit
public typealias SBJFont = NSFont
#endif
