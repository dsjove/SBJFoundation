import SBJUIVocabulary
import Foundation

import SBJDataDefinition
public extension FixedWidthInteger {
	var singleBitValue: Self? {
		(self != 0 && (self & (self - 1)) == 0) ? self : nil
	}
}

