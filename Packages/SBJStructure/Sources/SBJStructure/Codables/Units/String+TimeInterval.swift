import Foundation

public extension String {
    /// Parse colon-separated duration fields from the right (e.g. 1:02:03.5).
    /// The last whole-number field is the smallest whole unit in `units`.
    /// Out-of-bounds values carry naturally. Extra finer input units are
    /// truncated at the lower bound; fractional seconds round at whole seconds.
    func timeInterval(units: ClosedRange<DurationUnit> = .milliseconds ... .day) -> TimeInterval? {
        let smallest = units.lowerBound
        let largest = units.upperBound
        let permitted = DurationUnit.ordered.filter {
            $0 >= .second && $0 >= smallest && $0 <= largest
        }
        guard !permitted.isEmpty else { return nil }
        let fields = split(separator: ":", omittingEmptySubsequences: false)
        guard !fields.isEmpty else { return nil }
        // More input fields than display fields may supply finer units.
        // They are evaluated for carry, then precision beneath `smallest`
        // is truncated (or rounded when `smallest` is .second).
        let overflowFields = max(0, fields.count - permitted.count)
        let finerUnits = DurationUnit.ordered.filter {
            $0 >= .second && $0 < smallest
        }
        guard overflowFields <= finerUnits.count else { return nil }
        let extended = Array(finerUnits.suffix(overflowFields)) + permitted
        var total: Double = 0
        for (index, field) in fields.reversed().enumerated() {
            let unit = extended[index]
            let pieces = field.split(separator: ".", omittingEmptySubsequences: false)
            guard pieces.count == 1 || (index == 0 && unit == .second && pieces.count == 2),
                  !pieces[0].isEmpty,
                  pieces[0].allSatisfy({ $0.isASCII && $0.isNumber }),
                  let number = Double(pieces[0]), number.isFinite
            else { return nil }
            var value = number
            if pieces.count == 2 {
                let fraction = pieces[1]
                guard !fraction.isEmpty, fraction.count <= 3,
                      fraction.allSatisfy({ $0.isASCII && $0.isNumber }),
                      let fractional = Double("0." + fraction)
                else { return nil }
                value += fractional
            }
            total += value * unit.seconds
        }
        guard total.isFinite && total >= 0 else { return nil }
        // Milliseconds are the highest supported fractional precision.
        let quantum = smallest.seconds
        let normalized = smallest == .milliseconds
            ? (total / quantum).rounded() * quantum
            : (total / quantum).rounded(.towardZero) * quantum
        // If seconds are the smallest unit, round any fractional seconds.
        let result = smallest == .second ? total.rounded() : normalized
        return result.isFinite ? result : nil
    }

    var timestampInterval: TimeInterval? { timeInterval() }
    var normalizedTimestamp: String? { timestampInterval?.timestampString }
}

public extension TimeInterval {
    /// Display from the largest significant unit within the selected range.
    /// Fields after the first are zero-padded; trailing fractional zeros omitted.
    func timestampString(
        units: ClosedRange<DurationUnit> = .milliseconds ... .day,
        minimumWholeFields: Int = 1,
        fractionalDigits: Int? = nil
    ) -> String {
        guard isFinite, self >= 0,
              self < Double(Int64.max) / 1000 else { return "" }
        // With whole-second precision, distinguish positive subsecond times
        // from an actual zero-length interval.
        if fractionalDigits == 0 && units.lowerBound == .milliseconds {
            if self == 0 { return "0" }
            if self < 1 { return "\(Int((self * 1000).rounded()))ms" }
        }
        let small = units.lowerBound
        let wholeUnits = DurationUnit.ordered.filter {
            $0 >= .second && $0 >= small && $0 <= units.upperBound
        }.reversed()
        guard !wholeUnits.isEmpty else { return "" }
        let scaledMilliseconds = (self * 1000).rounded()
        // A floating-point value below the Int64 limit can still round up to
        // 2^63 when converted to milliseconds. Check the scaled value before conversion.
        guard scaledMilliseconds.isFinite,
              scaledMilliseconds >= 0,
              scaledMilliseconds < Double(Int64.max) else { return "" }
        let milliseconds = Int64(scaledMilliseconds)
        let quantum: Int64 = small == .milliseconds ? 1 : Int64(small.seconds * 1000)
        // Whole-second display precision must round BEFORE splitting the
        // duration into fields, so carry propagates (e.g. 65.5 -> 1:06).
        // Positive subsecond values were already handled above as milliseconds.
        let adjusted: Int64
        if fractionalDigits == 0 || small == .second {
            let roundedMilliseconds = (Double(milliseconds) / 1000).rounded() * 1000
            guard roundedMilliseconds.isFinite,
                  roundedMilliseconds < Double(Int64.max) else { return "" }
            adjusted = Int64(roundedMilliseconds)
        } else {
            adjusted = milliseconds / quantum * quantum
        }
        var remainder = adjusted / 1000
        var values: [Int64] = []
        for unit in wholeUnits {
            let divisor = Int64(unit.seconds)
            values.append(remainder / divisor)
            remainder %= divisor
        }
        let significant = values.firstIndex(where: { $0 != 0 }) ?? (values.count - 1)
        let first = min(significant, max(0, values.count - max(1, minimumWholeFields)))
        let text = values[first...].enumerated().map { index, value in
            index == 0 ? String(value) : String(format: "%02lld", value)
        }.joined(separator: ":")
        guard small == .milliseconds else { return text }
        var fractional = String(format: "%03lld", adjusted % 1000)
        if let fractionalDigits {
            let count = min(3, max(0, fractionalDigits))
            return count == 0 ? text : text + "." + String(fractional.prefix(count))
        }
        guard adjusted % 1000 != 0 else { return text }
        while fractional.last == "0" { fractional.removeLast() }
        return text + "." + fractional
    }

    var timestampString: String { timestampString() }
}
