#if !os(tvOS) && !os(watchOS)
import Foundation
import SwiftUI

//TODO: this appears to be an issue with dynamic type

enum SBJTextFieldWidth {
    /// Single-line text constraints are useful layout information, but maximum
    /// character count is not a literal pixel width. Use broad tiers so short
    /// domain values stay compact while ordinary prose remains flexible.
    static func singleLine(maximumLength: Int?) -> SBJFieldSizing? {
        guard let maximumLength else { return nil }
        switch maximumLength {
        case ...12:
            return SBJFieldSizing(minimum: 88, ideal: 120, maximum: 176)
        case 13...24:
            return SBJFieldSizing(minimum: 120, ideal: 180, maximum: 248)
        case 25...48:
            return SBJFieldSizing(minimum: 160, ideal: 240, maximum: 336)
        case 49...96:
            return SBJFieldSizing(minimum: 200, ideal: 320, maximum: 448)
        default:
            return nil
        }
    }
}
#endif
