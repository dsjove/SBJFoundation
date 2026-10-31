#if !os(watchOS) && !os(tvOS)
import SwiftUI
import SBJFileResources
import SBJDataDefinition
import SBJUIVocabulary

public extension SBJBundledContentReference {
    static var pageLayoutCore: SBJBundledContentReference {
        .help("Page Layout Core", resourceName: "PageLayoutCore", bundle: .module)
    }
}

/// Reusable page-layout controls without navigation chrome.
public struct PageLayoutEditorCore: View {
    @Binding private var pageLayout: PageLayout

    public init(pageLayout: Binding<PageLayout>) {
        _pageLayout = pageLayout
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                row("Page Size", info: PageLayout.pageSizeInfo) {
					SBJSelectionMenu(
						selection: Binding<Int?>(
							get: {
								PageSize.allCases.firstIndex(of: pageLayout.pageSize)
							},
							set: { index in
								guard let index,
									  PageSize.allCases.indices.contains(index)
								else { return }

								pageLayout.pageSize = PageSize.allCases[index]
							}
						),
						choices: PageSize.allCases.enumerated().map {
							SBJMenuChoice(
								id: $0.offset,
								title: $0.element.description
							)
						},
						currentTitle: pageLayout.pageSize.description
					)
					.frame(width: 180, alignment: .trailing)
				}
                row("Landscape", info: PageLayout.landscapeInfo) {
                    Toggle("Landscape", isOn: $pageLayout.landscape).labelsHidden()
                }
                marginRow("Left", value: $pageLayout.left, info: PageLayout.leftInfo)
                marginRow("Right", value: $pageLayout.right, info: PageLayout.rightInfo)
                marginRow("Top", value: $pageLayout.top, info: PageLayout.topInfo)
                marginRow("Bottom", value: $pageLayout.bottom, info: PageLayout.bottomInfo)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private func marginRow(_ name: String, value: Binding<UnitValue<LengthUnit>>, info: SBJPropertyInfo) -> some View {
        row(name, info: info) {
            UnitValueControl(value: value, accessibilityLabel: name, propertyInfo: info)
        }
    }

    private func row<Control: View>(
        _ name: String, info: SBJPropertyInfo,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)
            control()
                .frame(width: 180, alignment: .trailing)
            SBJPropertyInfoButton(propertyName: name, info: info)
                .frame(width: 32)
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .contain)
    }
}

/// Navigation wrapper retained for existing callers.
public struct PageLayoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pageLayout: PageLayout
    @State private var originalPageLayout: PageLayout
    private let onChange: (PageLayout) -> Void

    public init(pageLayout: PageLayout, onChange: @escaping (PageLayout) -> Void) {
        _pageLayout = State(initialValue: pageLayout)
        _originalPageLayout = State(initialValue: pageLayout)
        self.onChange = onChange
    }

    public var body: some View {
        NavigationStack {
            PageLayoutEditorCore(pageLayout: $pageLayout)
                .navigationTitle("Page Layout")
                .sbjInlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Restore") { pageLayout = originalPageLayout }
                            .disabled(pageLayout == originalPageLayout)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .onChange(of: pageLayout) { _, newValue in onChange(newValue) }
        }
    }
}
#endif
