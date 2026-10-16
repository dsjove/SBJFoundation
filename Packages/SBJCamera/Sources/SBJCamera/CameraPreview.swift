import SwiftUI

#if os(iOS) || os(macOS)
import AVFoundation

protocol CameraPreviewSource: AnyObject {
    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer)
    func detachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer)
}

#if canImport(UIKit)
import UIKit

public struct CameraPreview: UIViewRepresentable {
    private let camera: any Camera

    public init(camera: any Camera) {
        self.camera = camera
    }

    public final class Coordinator {
        fileprivate let camera: any Camera

        fileprivate init(camera: any Camera) {
            self.camera = camera
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(camera: camera)
    }

    public func makeUIView(context: Context) -> UIView {
        let view = PreviewView()
        (camera as? any CameraPreviewSource)?.attachPreviewLayer(view.videoPreviewLayer)
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? PreviewView else { return }
        (camera as? any CameraPreviewSource)?.attachPreviewLayer(view.videoPreviewLayer)
    }

    public static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        guard let view = uiView as? PreviewView else { return }
        (coordinator.camera as? any CameraPreviewSource)?.detachPreviewLayer(view.videoPreviewLayer)
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

}

#elseif canImport(AppKit)
import AppKit

public struct CameraPreview: NSViewRepresentable {
    private let camera: any Camera

    public init(camera: any Camera) {
        self.camera = camera
    }

    public final class Coordinator {
        fileprivate let camera: any Camera

        fileprivate init(camera: any Camera) {
            self.camera = camera
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(camera: camera)
    }

    public func makeNSView(context: Context) -> NSView {
        let view = PreviewView()
        (camera as? any CameraPreviewSource)?.attachPreviewLayer(view.videoPreviewLayer)
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? PreviewView else { return }
        (camera as? any CameraPreviewSource)?.attachPreviewLayer(view.videoPreviewLayer)
    }

    public static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        guard let view = nsView as? PreviewView else { return }
        (coordinator.camera as? any CameraPreviewSource)?.detachPreviewLayer(view.videoPreviewLayer)
    }
}

private final class PreviewView: NSView {
    override func makeBackingLayer() -> CALayer {
        AVCaptureVideoPreviewLayer()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

}
#endif

#else

/// A compile-safe placeholder on Apple platforms that don't expose ordinary
/// still-camera capture to this package.
public struct CameraPreview: View {
    public init(camera: any Camera) { }

    public var body: some View {
        EmptyView()
    }
}
#endif
