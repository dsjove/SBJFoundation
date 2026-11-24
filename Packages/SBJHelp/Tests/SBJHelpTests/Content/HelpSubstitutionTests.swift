import Foundation
import XCTest
@testable import SBJHelp

final class HelpSubstitutionTests: XCTestCase {
    func testOverlappingNamesPreferLongestMatch() {
        let source = "PRIVACY_URL URL"
        XCTAssertEqual(
            source.replacingOccurrences(using: ["URL": "https://example.test", "PRIVACY_URL": "https://privacy.test"]),
            "https://privacy.test https://example.test"
        )
    }

    func testReplacementValuesAreNotExpandedAgain() {
        let source = "CONTENT"
        XCTAssertEqual(
            source.replacingOccurrences(using: ["CONTENT": "URL and TITLE", "URL": "example", "TITLE": "Welcome"]),
            "URL and TITLE"
        )
    }

    func testTokensAreNotReplacedInsideOtherIdentifiers() {
        XCTAssertEqual(
            "UNKNOWN MY_KNOWN KNOWN_SUFFIX KNOWN. (KNOWN)".replacingOccurrences(using: ["KNOWN": "ok"]),
            "UNKNOWN MY_KNOWN KNOWN_SUFFIX ok. (ok)"
        )
    }

    func testEmptyKeysAreIgnoredAndUnknownTokensRemain() {
        XCTAssertEqual(
            "KNOWN UNKNOWN".replacingOccurrences(using: ["": "bad", "KNOWN": "ok"]),
            "ok UNKNOWN"
        )
    }
}
