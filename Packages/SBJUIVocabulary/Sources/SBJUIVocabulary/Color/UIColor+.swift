import UIKit

import SBJDataDefinition
public extension UIColor {
	var brightness: CGFloat {
		var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
		getRed(&red, green: &green, blue: &blue, alpha: &alpha)
		return (red * 299 + green * 587 + blue * 114) / 1000
	}
	
	var isLight: Bool {
		brightness > 0.5
	}
}
