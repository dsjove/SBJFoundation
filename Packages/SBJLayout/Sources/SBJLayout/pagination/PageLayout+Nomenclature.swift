import SBJDataDefinition
import SBJLocalization

@SBJPropertyInfo
extension PageLayout: StringPresentable {
	public var description: String {
		"\(pageSize), \(landscape ? "landscape" : "portrait"), margins: top \(top), bottom \(bottom), left \(left), right \(right)"
	}
	public static let pageSizeInfo = SBJPropertyInfo(
		summary: "Paper size used for PDF layout.",
		details: "The preferred unit for margins is inches, or millimeters for ISO A paper sizes. Changing paper-size families converts existing measurements without altering physical distances."
	)
	public static let landscapeInfo = SBJPropertyInfo(
		summary: "Use landscape page orientation rather than portrait."
	)
	public static let topInfo = SBJPropertyInfo(
		summary: "Top page margin."
	)
	public static let bottomInfo = SBJPropertyInfo(
		summary: "Bottom page margin."
	)
	public static let leftInfo = SBJPropertyInfo(
		summary: "Left page margin."
	)
	public static let rightInfo = SBJPropertyInfo(
		summary: "Right page margin."
	)
}
