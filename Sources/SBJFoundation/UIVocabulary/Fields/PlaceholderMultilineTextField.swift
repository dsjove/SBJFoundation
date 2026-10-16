#if !os(watchOS) && !os(tvOS)
import SwiftUI
#if canImport(UIKit)
import UIKit
import SBJLocalization
#endif

/// A compact multiline text field that can promote input into a sheet when more
/// room is useful. Inline and sheet presentations use the same field chrome.
public struct PlaceholderMultilineTextField<Placeholder: View>: View {
    @Binding var text: String
    let placeholder: Placeholder
    let numberOfLines: Int

    @State private var showSheet = false
    @FocusState private var isFocused: Bool
    @FocusState private var sheetIsFocused: Bool

    public init(
        @ViewBuilder _ placeholder: () -> Placeholder,
        text: Binding<String>,
        numberOfLines: Int = 3
    ) {
        self._text = text
        self.numberOfLines = numberOfLines
        self.placeholder = placeholder()
    }

    public init(
        _ placeholder: String,
        text: Binding<String>,
        numberOfLines: Int = 3
    ) where Placeholder == Text {
        self._text = text
        self.numberOfLines = numberOfLines
        self.placeholder = Text(placeholder)
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .sbjMultilineField(isFocused: $isFocused, minHeight: estimatedHeight)
                .sbjApplyTextInputPolicies(autocorrection: .automatic, capitalization: .automatic)
                .padding(.trailing, 32)

            if text.isEmpty {
                placeholder
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                SBJImageButton(
                    SBJSymbology.edit,
                    accessibilityLabel: "Edit in sheet"
                ) {
                    showSheet = true
                }
                .padding(.trailing, 8)
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                TextEditor(text: $text)
                    .sbjMultilineField(isFocused: $sheetIsFocused, minHeight: 220)
                    .sbjApplyTextInputPolicies(autocorrection: .automatic, capitalization: .automatic)
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            placeholder
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showSheet = false
                            }
                        }
                    }
                    .onAppear { sheetIsFocused = true }
            }
        }
    }

    private var estimatedHeight: CGFloat {
#if canImport(UIKit)
        let lineHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight
#else
        let lineHeight: CGFloat = 20
#endif
        return lineHeight * CGFloat(max(1, numberOfLines)) + 16
    }
}
#endif
