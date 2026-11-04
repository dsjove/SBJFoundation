#if !os(watchOS)
#if canImport(UIKit)
import UIKit
import SBJFileResources
import SBJDataDefinition
import SBJUIVocabulary

public typealias IdentifiableImage = Identified<UIImage>

public extension UIImage {
	convenience init?(data: Data?) {
		guard let data else {
			return nil
		}
		self.init(data: data)
	}

	convenience init?(url: URL?) {
		guard let url else {
			return nil
		}
		guard let data = url.withSecurityScopedAccess({ try? Data(contentsOf: $0) }) else {
			return nil
		}
		self.init(data: data)
	}
}

#endif
#endif
