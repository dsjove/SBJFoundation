import Foundation

/// Numeric presentation policy for numeric values.
///
/// Callers choose the desired decimal precision or fractional representation.
public enum SBJNumberFormatStyle: Sendable, Equatable, Hashable {
    case decimal(significantDigits: Int)
    case fraction(fallbackSignificantDigits: Int)

    public func format(_ value: Double) -> String {
        switch self {
        case .decimal(let significantDigits):
            decimalString(for: value, significantDigits: significantDigits)
        case .fraction(let fallbackSignificantDigits):
            fractionString(for: value)
                ?? decimalString(for: value, significantDigits: fallbackSignificantDigits)
        }
    }
}

private func decimalString(for value: Double, significantDigits: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesSignificantDigits = true
    formatter.maximumSignificantDigits = max(1, significantDigits)
    formatter.minimumSignificantDigits = 1
    return formatter.string(from: value as NSNumber) ?? "\(value)"
}

private func fractionString(for value: Double) -> String? {
    if value.isNaN || value.isInfinite { return nil }
    let absValue = abs(value)
    if absValue > 10_000 { return nil }
    let whole = Int(value.rounded(.towardZero))
    let fractional = abs(value - Double(whole))
    if abs(fractional) < 1e-6 { return "\(whole)" }
    let denominators = [2, 3, 4, 5, 6, 8, 10, 12, 16]
    var bestNumerator: Int?
    var bestDenominator: Int?
    var bestError = Double.greatestFiniteMagnitude
    for denominator in denominators {
        let numerator = (fractional * Double(denominator)).rounded()
        let error = abs(Double(numerator) / Double(denominator) - fractional)
        if error < bestError {
            bestError = error
            bestNumerator = Int(numerator)
            bestDenominator = denominator
        }
    }
    guard let numerator = bestNumerator,
          let denominator = bestDenominator,
          bestError < 0.01 else { return nil }

    var carryWhole = whole
    var num = numerator
    var den = denominator
    if num == den {
        carryWhole += value >= 0 ? 1 : -1
        num = 0
    }
    if num != 0 {
        let divisor = gcd(abs(num), den)
        num /= divisor
        den /= divisor
    }
    let sign = value < 0 && carryWhole == 0 && num > 0 ? "-" : ""
    if num == 0 { return "\(carryWhole)" }
    if carryWhole == 0 { return "\(sign)\(num)/\(den)" }
    return "\(carryWhole) \(num)/\(den)"
}

private func gcd(_ a: Int, _ b: Int) -> Int {
    var x = a
    var y = b
    while y != 0 {
        let remainder = x % y
        x = y
        y = remainder
    }
    return max(1, x)
}

extension String {
	/// Advance an existing trailing collision number, or append the first one.
	/// Numbering precedes the filename extension, when present.
	/// `number` is an offset from the current suffix (or zero if none).
	public func appendingNumber(_ number: Int) -> String {
		guard number > 0 else { return self }
		let dot = lastIndex(of: ".").flatMap { position -> String.Index? in
			guard position != startIndex, index(after: position) != endIndex,
				  (lastIndex(of: "/").map { $0 < position } ?? true) else { return nil }
			return position
		}
		let stem = String(dot.map { self[..<$0] } ?? self[...])
		let suffix = dot.map { String(self[$0...]) } ?? ""
		let parts = stem.split(separator: " ", omittingEmptySubsequences: false)
		if let last = parts.last, let previous = Int(last), previous >= 0,
		   !previous.addingReportingOverflow(number).overflow {
			let base = parts.dropLast().joined(separator: " ")
			if !base.isEmpty { return "\(base) \(previous + number)\(suffix)" }
		}
		return "\(stem) \(number)\(suffix)"
	}
}
