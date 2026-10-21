#if canImport(UIKit)
import UIKit
import SBJDataDefinition
import SBJFileResources
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

	func resized(toFit size: CGSize) -> UIImage {
		guard size.width > 0, size.height > 0,
			  self.size.width > 0, self.size.height > 0
		else {
			return self
		}

		let scale = min(
			1,
			size.width / self.size.width,
			size.height / self.size.height
		)

		guard scale < 1 else {
			return self
		}

		let targetSize = CGSize(
			width: self.size.width * scale,
			height: self.size.height * scale
		)

		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.opaque = false

		return UIGraphicsImageRenderer(
			size: targetSize,
			format: format
		).image { _ in
			draw(in: CGRect(origin: .zero, size: targetSize))
		}
	}
}

#endif
