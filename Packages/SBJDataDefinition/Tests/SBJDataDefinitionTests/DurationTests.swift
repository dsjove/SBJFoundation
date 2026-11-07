import Foundation
import Testing
@testable import SBJDataDefinition

@SBJStructure
private struct DurationFixture: Codable {
    @SBJDuration(units: .second ... .hour)
    var runningTime: TimeInterval = 73.5
}

@Test func durationParsingAndFormatting() {
    #expect("1:75:90.500".timestampInterval == 8190.5)
    #expect("1:75:90.500".normalizedTimestamp == "2:16:30.5")
    #expect("0:0:3.050".normalizedTimestamp == "3.05")
    #expect("0:0:75".normalizedTimestamp == "1:15")
    #expect("1:2:3".normalizedTimestamp == "1:02:03")
    #expect("1:02.5".timeInterval(units: .second ... .hour) == 63)
    #expect("1:02.4".timeInterval(units: .second ... .hour) == 62)
    #expect("75:90".timeInterval(units: .minute ... .hour) == 275400)
    #expect("1:2:3".timeInterval(units: .minute ... .hour) == 3720)
    #expect(TimeInterval(3723.5).timestampString(units: .second ... .hour) == "1:02:04")
    #expect(TimeInterval(0).timestampString == "0")
}

@Test func durationAnnotationIsStructuralMetadata() {
    let metadata = DurationFixture.propertyMetadata(for: \.runningTime)
    #expect(metadata?.constraints.contains(.durationRules(.init(units: .second ... .hour))) == true)
}
    @Test func timestampFormattingForMovieViewer() {
        #expect(TimeInterval(65.2).timestampString(minimumWholeFields: 2, fractionalDigits: 3) == "1:05.200")
        #expect(TimeInterval(0).timestampString(minimumWholeFields: 2, fractionalDigits: 3) == "0:00.000")
        #expect(TimeInterval(3661.005).timestampString(minimumWholeFields: 3, fractionalDigits: 3) == "1:01:01.005")
        #expect(TimeInterval(35.280).timestampString(minimumWholeFields: 2, fractionalDigits: 3) == "0:35.280")
        #expect(TimeInterval(3661.005).timestampString(minimumWholeFields: 2, fractionalDigits: 3) == "1:01:01.005")
    }

@Test func durationUnitFromMaximumMovieTime() {
    #expect(DurationUnit(0) == .second)
    #expect(DurationUnit(0.999) == .second)
    #expect(DurationUnit(59.999) == .second)
    #expect(DurationUnit(60) == .minute)
    #expect(DurationUnit(3599.999) == .minute)
    #expect(DurationUnit(3600) == .hour)
    #expect(DurationUnit(86399.999) == .hour)
    #expect(DurationUnit(86400) == .day)
}

@Test func movieTimeFormatUsesMaximumFrameUnit() {
    func format(_ current: TimeInterval, maximum: TimeInterval, digits: Int = 3) -> String {
        let unit = DurationUnit(maximum)
        return current.timestampString(
            units: .milliseconds ... unit,
            minimumWholeFields: unit.timestampWholeFields,
            fractionalDigits: digits
        )
    }
    #expect(format(0.999, maximum: 0.999) == "0.999")
    #expect(format(59.999, maximum: 59.999) == "59.999")
    #expect(format(59.999, maximum: 60) == "0:59.999")
    #expect(format(3599.999, maximum: 3599.999) == "59:59.999")
    #expect(format(46799.999, maximum: 46799.999) == "12:59:59.999")
    #expect(format(0.5, maximum: 60, digits: 0) == "500ms")
    #expect(format(0.999, maximum: 60, digits: 0) == "999ms")
    #expect(format(0.001, maximum: 60, digits: 0) == "1ms")
    #expect(format(0, maximum: 60, digits: 0) == "0")
    #expect(format(65.5, maximum: 120, digits: 0) == "1:06")
}
