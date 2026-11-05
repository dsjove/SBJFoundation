import Foundation
import CoreImage
import CoreGraphics
import SBJLocalization
import SBJDataDefinition
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Non-destructive tonal adjustments. All zero values preserve the source.
/// Compatible with old image documents whose color recipe was `{}`.
@SBJStructure
public struct PhotoColorAdjustments: Codable, Equatable, Sendable {
    @SBJNumber(range: -2.0...2.0)
    public var exposure: Double = 0       // EV, -2...2
    @SBJNumber(range: -1.0...1.0)
    public var shadows: Double = 0        // -1...1
    @SBJNumber(range: -1.0...1.0)
    public var highlights: Double = 0     // -1...1
    @SBJNumber(range: -1.0...1.0)
    public var contrast: Double = 0       // -1...1
    @SBJNumber(range: -1.0...1.0)
    public var saturation: Double = 0     // -1...1
    @SBJNumber(range: 0.0...1.0)
    public var detail: Double = 0         // 0...1
    @SBJNumber(range: 0.0...1.0)
    public var noiseReduction: Double = 0 // 0...1

    public init() {}

    public var isNeutral: Bool { self == Self() }
    public static var dark: Self {
        var s = Self(); s.exposure = 0.35; s.shadows = 0.65; s.highlights = -0.15; s.detail = 0.15
        return s
    }
    public static var faded: Self {
        var s = Self(); s.contrast = 0.3; s.saturation = 0.22; s.detail = 0.2
        return s
    }
    public static var grainy: Self {
        var s = Self(); s.noiseReduction = 0.35; s.detail = 0.12
        return s
    }

    private enum CodingKeys: String, CodingKey {
        case exposure, shadows, highlights, contrast, saturation, detail, noiseReduction
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exposure = try c.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
        shadows = try c.decodeIfPresent(Double.self, forKey: .shadows) ?? 0
        highlights = try c.decodeIfPresent(Double.self, forKey: .highlights) ?? 0
        contrast = try c.decodeIfPresent(Double.self, forKey: .contrast) ?? 0
        saturation = try c.decodeIfPresent(Double.self, forKey: .saturation) ?? 0
        detail = try c.decodeIfPresent(Double.self, forKey: .detail) ?? 0
        noiseReduction = try c.decodeIfPresent(Double.self, forKey: .noiseReduction) ?? 0
    }

    /// Uses new filter instances per call; safe to apply from AVFoundation's render queue.
    public func applying(to source: CIImage) -> CIImage {
        guard !isNeutral else { return source }
        var image = source
        func apply(_ name: String, _ inputs: [String: Any]) {
            guard let filter = CIFilter(name: name) else { return }
            filter.setValue(image, forKey: kCIInputImageKey)
            for (key, value) in inputs { filter.setValue(value, forKey: key) }
            image = filter.outputImage ?? image
        }
        if exposure != 0 {
            apply("CIExposureAdjust", [kCIInputEVKey: exposure.clamped(to: -2...2)])
        }
        if shadows != 0 || highlights != 0 {
            apply("CIHighlightShadowAdjust", [
                "inputShadowAmount": shadows.clamped(to: -1...1),
                "inputHighlightAmount": (1 + highlights.clamped(to: -1...1)).clamped(to: 0...2)
            ])
        }
        if contrast != 0 || saturation != 0 {
            apply("CIColorControls", [
                kCIInputContrastKey: 1 + contrast.clamped(to: -1...1),
                kCIInputSaturationKey: 1 + saturation.clamped(to: -1...1)
            ])
        }
        if noiseReduction > 0 {
            apply("CINoiseReduction", [
                "inputNoiseLevel": 0.02 + noiseReduction.clamped(to: 0...1) * 0.06,
                "inputSharpness": 0.4
            ])
        }
        if detail > 0 {
            apply("CISharpenLuminance", ["inputSharpness": detail.clamped(to: 0...1) * 1.3])
        }
        return image
    }

    public func applying(to image: CGImage, context: CIContext = CIContext()) -> CGImage? {
        guard !isNeutral else { return image }
        let input = CIImage(cgImage: image)
        let output = applying(to: input)
        return context.createCGImage(output, from: input.extent)
    }

    #if canImport(UIKit) || canImport(AppKit)
    public func applying(to image: SBJImage, context: CIContext = CIContext()) -> SBJImage? {
        guard !isNeutral else { return image }
        guard let source = image.sbjCGImage,
              let result = applying(to: source, context: context) else { return nil }
        return image.sbjReplacingPixels(with: result)
    }
    #endif

}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double { min(max(self, range.lowerBound), range.upperBound) }
}

// Native image representation belongs at the platform boundary. The filter
// implementation above has one code path on both platforms.
#if canImport(UIKit)
private extension SBJImage {
    func sbjReplacingPixels(with image: CGImage) -> SBJImage {
        UIImage(cgImage: image, scale: scale, orientation: imageOrientation)
    }
}
#elseif canImport(AppKit)
private extension SBJImage {
    func sbjReplacingPixels(with image: CGImage) -> SBJImage {
        NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
#endif
