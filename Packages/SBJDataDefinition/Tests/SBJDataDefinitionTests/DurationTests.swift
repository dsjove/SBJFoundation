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
