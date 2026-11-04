#if os(iOS) || os(visionOS)
import SwiftUI
import UIKit
import SBJDataDefinition

// The public sheet-facing ColorPickerView API is shared across platforms.
// UIKit's UIColorPickerViewController preserves the iOS interaction while
// macOS uses the native SwiftUI ColorPicker and system color panel.
// TODO: Compare the direct ColorPicker in SBJColorEditor with this wrapper
// before attempting to merge their distinct presentation behaviors.

public struct ColorPickerView: UIViewControllerRepresentable {
	private let title: String
	@Binding private var selectedColor: Color

	public init(title: String, selectedColor: Binding<Color>) {
		self.title = title
		self._selectedColor = selectedColor
	}

	public class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
		var parent: ColorPickerView

		init(parent: ColorPickerView) {
			self.parent = parent
		}

		public func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {}

		public func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
			parent.selectedColor = Color(uiColor: color)
		}
	}

	public func makeCoordinator() -> Coordinator {
		Coordinator(parent: self)
	}

	public func makeUIViewController(context: Context) -> UIColorPickerViewController {
		let picker = UIColorPickerViewController()
		picker.title = title
		picker.delegate = context.coordinator
		picker.supportsAlpha = true
		if #available(iOS 26.0, *) {
			//picker.supportsEyedropper = false
		}
		picker.selectedColor = UIColor(selectedColor)
		picker.view.backgroundColor = .systemBackground
		return picker
	}

	public func updateUIViewController(_ uiViewController: UIColorPickerViewController, context: Context) {}
}
#endif

#if os(macOS)
import SwiftUI

/// Native macOS color editing, presented using the same sheet-facing API as iOS.
/// SwiftUI's ColorPicker uses the system color panel; no custom AppKit panel
/// coordination or parallel color conversion is needed.
public struct ColorPickerView: View {
    private let title: String
    @Binding private var selectedColor: Color
    @Environment(\.dismiss) private var dismiss

    public init(title: String, selectedColor: Binding<Color>) {
        self.title = title
        self._selectedColor = selectedColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ColorPicker(title, selection: $selectedColor, supportsOpacity: true)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 300)
    }
}
#endif
