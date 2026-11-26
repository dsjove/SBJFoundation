import SBJLocalization
import SBJStructure

@SBJStructureExtension
extension PageLayout: SBJTextPresentable {
	@SBJExclude
	public var presentedValue: String {
		"\(pageSize), \(landscape ? "landscape" : "portrait"), margins: top \(top), bottom \(bottom), left \(left), right \(right)"
	}
	public static let pageSizeNomenclature = #SBJAutoNomenclature(summary: "Paper size used for PDF layout.",
		details: "The preferred unit for margins is inches, or millimeters for ISO A paper sizes. Changing paper-size families converts existing measurements without altering physical distances."
	)
	public static let landscapeNomenclature = #SBJAutoNomenclature(summary: "Use landscape page orientation rather than portrait."
	)
	public static let topNomenclature = #SBJAutoNomenclature(summary: "Top page margin."
	)
	public static let bottomNomenclature = #SBJAutoNomenclature(summary: "Bottom page margin."
	)
	public static let leftNomenclature = #SBJAutoNomenclature(summary: "Left page margin."
	)
	public static let rightNomenclature = #SBJAutoNomenclature(summary: "Right page margin."
	)
}
