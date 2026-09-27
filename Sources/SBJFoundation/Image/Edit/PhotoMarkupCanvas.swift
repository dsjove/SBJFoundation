#if !os(watchOS) && !os(tvOS) && canImport(UIKit) && canImport(PencilKit)
import Foundation
import Observation
import PencilKit
import SwiftUI

@MainActor
@Observable
final class PhotoMarkupState {
    enum Tool: Sendable {
        case pen
        case eraser
        case lasso
    }

    private(set) var drawing: PKDrawing
    private(set) var canvasSize: CGSize
    private(set) var canUndo = false
    private(set) var canRedo = false
    var selectedTool: Tool = .pen {
        didSet { applySelectedTool() }
    }
    var inkColor: Color = .black {
        didSet { applySelectedTool() }
    }

    let toolPicker = PKToolPicker()
    weak var canvas: PKCanvasView?

    init(drawing: PKDrawing = PKDrawing(), canvasSize: CGSize = .zero) {
        self.drawing = drawing
        self.canvasSize = canvasSize
    }

    var hasDrawing: Bool { !drawing.bounds.isEmpty }
    var extendedToolsSupported: Bool { !ProcessInfo.isAnyMac }

    var markup: PhotoMarkup? {
        guard hasDrawing, canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        return PhotoMarkup(drawing: drawing, canvasSize: canvasSize)
    }

    var drawingForRendering: PKDrawing { drawing }
    var canvasSizeForRendering: CGSize { canvasSize }

    func updateCanvasSize(_ size: CGSize) {
        canvasSize = size
    }

    func clear() {
        drawing = PKDrawing()
        canvas?.drawing = drawing
        canvas?.undoManager?.removeAllActions()
        refreshUndoState()
    }

    func undo() {
        canvas?.undoManager?.undo()
        syncFromCanvas()
    }

    func redo() {
        canvas?.undoManager?.redo()
        syncFromCanvas()
    }

    func syncFromCanvas() {
        if let canvas { drawingDidChange(canvas.drawing) }
        refreshUndoState()
    }

    func drawingDidChange(_ drawing: PKDrawing) {
        self.drawing = drawing
    }

    func refreshUndoState() {
        canUndo = canvas?.undoManager?.canUndo ?? false
        canRedo = canvas?.undoManager?.canRedo ?? false
    }

    func attach(_ canvas: PKCanvasView) {
        guard self.canvas !== canvas else { return }

        if let oldCanvas = self.canvas {
            if extendedToolsSupported {
                toolPicker.setVisible(false, forFirstResponder: oldCanvas)
                toolPicker.removeObserver(oldCanvas)
            }
            oldCanvas.resignFirstResponder()
        }

        self.canvas = canvas
        if extendedToolsSupported {
            toolPicker.addObserver(canvas)
        }
        applySelectedTool()
    }

    func setActive(_ active: Bool) {
        guard let canvas else { return }

        canvas.isUserInteractionEnabled = active

        guard extendedToolsSupported else {
            if !active { canvas.resignFirstResponder() }
            return
        }

        if active {
            // Use PencilKit's public responder-driven presentation path directly.
            // Re-adding the observer is harmless and makes the activation sequence
            // self-contained when SwiftUI moves/rehosts the canvas.
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
            canvas.becomeFirstResponder()
        } else {
            toolPicker.setVisible(false, forFirstResponder: canvas)
            canvas.resignFirstResponder()
        }
    }

    func select(_ tool: Tool) {
        selectedTool = tool
    }

    private func applySelectedTool() {
        guard let canvas else { return }

        switch selectedTool {
        case .pen:
            canvas.tool = PKInkingTool(.pen, color: UIColor(inkColor), width: 5)
        case .eraser:
            canvas.tool = PKEraserTool(.vector)
        case .lasso:
            canvas.tool = PKLassoTool()
        }
    }

    func detach(_ canvas: PKCanvasView) {
        if extendedToolsSupported {
            toolPicker.setVisible(false, forFirstResponder: canvas)
            toolPicker.removeObserver(canvas)
        }
        canvas.resignFirstResponder()

        if self.canvas === canvas {
            self.canvas = nil
        }
    }
}

struct PhotoMarkupCanvas: UIViewRepresentable {
    let model: PhotoMarkupState
    let isActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawingPolicy = .anyInput
        view.delegate = context.coordinator
        view.drawing = model.drawing
        model.attach(view)
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        model.attach(view)
        model.setActive(isActive)
        model.refreshUndoState()
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.model.detach(uiView)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let model: PhotoMarkupState

        init(model: PhotoMarkupState) {
            self.model = model
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            model.drawingDidChange(canvasView.drawing)
            model.refreshUndoState()
        }
    }
}
#endif
