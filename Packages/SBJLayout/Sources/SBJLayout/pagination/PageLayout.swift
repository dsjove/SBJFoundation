import Foundation
import SBJDataDefinition
import SBJDataDefinition

@SBJStructure
public struct PageLayout: Codable, Equatable, Sendable {
	public var pageSize: PageSize {
		didSet {
			let unit = pageSize.marginUnit
			guard oldValue.marginUnit != unit else { return }
			top = top.converted(to: unit)
			bottom = bottom.converted(to: unit)
			left = left.converted(to: unit)
			right = right.converted(to: unit)
		}
	}
	public var landscape: Bool
	@SBJUnitValue(immutableUnit: true)
	public var left: UnitValue<LengthUnit>
	@SBJUnitValue(immutableUnit: true)
	public var right: UnitValue<LengthUnit>
	@SBJUnitValue(immutableUnit: true)
	public var top: UnitValue<LengthUnit>
	@SBJUnitValue(immutableUnit: true)
	public var bottom: UnitValue<LengthUnit>

	public init(
		pageSize: PageSize = .letter,
		landscape: Bool = false,
		left: UnitValue<LengthUnit>? = nil,
		right: UnitValue<LengthUnit>? = nil,
		top: UnitValue<LengthUnit>? = nil,
		bottom: UnitValue<LengthUnit>? = nil
	) {
		self.pageSize = pageSize
		self.landscape = landscape
		let defaultMargin = pageSize.defaultMargin
		self.top = top ?? defaultMargin
		self.bottom = bottom ?? defaultMargin
		self.left = left ?? defaultMargin
		self.right = right ?? defaultMargin
	}

	public var pageRect: CGRect {
		pageSize.rect(landscape: landscape, margin: .zero)
	}

	public var printableRect: CGRect {
		pageSize.rect(landscape: landscape, margin: marginsInPDFPoints)
	}

	/// PDF rendering geometry; all unit conversion stays on PageLayout.
	public var marginsInPDFPoints: Insets {
		Insets(
			left: CGFloat(left.converted(to: .point).value),
			right: CGFloat(right.converted(to: .point).value),
			top: CGFloat(top.converted(to: .point).value),
			bottom: CGFloat(bottom.converted(to: .point).value)
		)
	}
}
