import Foundation

public struct CapturedAttachment: Sendable {
	public let blob: Data
	public let utiType: String

	public init(blob: Data, utiType: String) {
		self.blob = blob
		self.utiType = utiType
	}
}
