import CoreGraphics

public struct TrackFactory {
	public static let placeholderIndex = -1

	let minCount: Int
	let maxCount: Int
	let def: (Int)->Track

	public init(
		_ length: TrackSize = .intrinsic(),
		align: Alignment = .top,
		gap: CGFloat = 3.0,
		aggregate: @escaping Track.Aggregate = { $0.max() },
		minCount: Int = 0,
		maxCount: Int = Int.max
	) {
		self.init(minCount: minCount, maxCount: maxCount) { _ in
			.init(length, align: align, gap: gap, aggregate: aggregate)
		}
	}

	public init(
		col track: Track
	) {
		self.init(minCount: 1, maxCount: 1) { _ in track }
	}

	public init(
		row track: Track,
		minCount: Int = 0,
		maxCount: Int = Int.max
	) {
		self.init(minCount: minCount, maxCount: maxCount) { _ in track }
	}

	public init(
		_ tracks: [Track],
		map: ((Int) -> Int)? = nil
	) {
		self.init(
			minCount: tracks.isEmpty ? 0 : 1,
			maxCount: tracks.count
		) { index in
			tracks[map.map { $0(index) } ?? index]
		}
	}

	public init(
		minCount: Int = 0,
		maxCount: Int = Int.max,
		def: @escaping (Int) -> Track
	) {
		let minCount = Swift.max(0, minCount)
		let maxCount = Swift.max(0, maxCount)
		self.minCount = minCount
		self.maxCount = Swift.max(minCount, maxCount)
		self.def = def
	}
}
