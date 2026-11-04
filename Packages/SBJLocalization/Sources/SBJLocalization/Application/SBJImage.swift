// A native image type shared by the UIKit and AppKit platforms.
// Keep native rendering differences in extensions rather than duplicating callers.
#if canImport(UIKit)
import UIKit
public typealias SBJImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias SBJImage = NSImage
#endif
