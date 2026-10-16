import SwiftUI
import SBJLocalization

public struct SBJSelectionMenu<Content: View>: View {
    @ViewBuilder let content: () -> Content
    private let collapsedContent: (() -> AnyView)?
    private let menuLabel: () -> AnyView
    private var selectionView: (() -> AnyView)? = nil

    public init(
        _ title: LocalizedStringKey,
        image: ImageReference,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.collapsedContent = nil
        self.menuLabel = { AnyView(Label(title, image: image)) }
    }

    public init(
        _ title: LocalizedStringKey,
        symbol: SBJSymbol,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.collapsedContent = nil
        self.menuLabel = { AnyView(Label(title, symbol: symbol)) }
    }

    /// Uses a custom menu label and, optionally, a separately-rendered form for the
    /// single-item case. `collapsedContent` should produce the same logical actions
    /// as `content`; it exists only so callers can adjust their presentation when the
    /// menu collapses to one action.
    public init<CollapsedContent: View, MenuLabel: View>(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder collapsedContent: @escaping () -> CollapsedContent,
        @ViewBuilder label: @escaping () -> MenuLabel
    ) {
        self.content = content
        self.collapsedContent = { AnyView(collapsedContent()) }
        self.menuLabel = { AnyView(label()) }
    }

    /// Compatibility convenience for callers that currently name an SF Symbol directly.
    /// Semantic callers should use the `symbol:` initializer; `image:` accepts any ImageReference.
    public init(
        _ title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(title, image: .system(systemImage), content: content)
    }

    @ViewBuilder
    public var body: some View {
        if let selectionView {
            selectionView()
        } else {
#if os(watchOS)
        content()
#else
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *) {
            collapsingBody
        } else {
            menuBody
        }
#endif
        }
    }

#if !os(watchOS)
    private var menuBody: some View {
        Menu {
            content()
                .labelStyle(.titleAndIcon)
        } label: {
            menuLabel()
        }
        .menuOrder(.fixed)
    }

    @available(iOS 18.0, macOS 15.0, tvOS 18.0, visionOS 2.0, *)
    @ViewBuilder
    private var collapsingBody: some View {
        Group(subviews: content()) { subviews in
            if subviews.isEmpty {
                EmptyView()
            } else if subviews.count == 1 {
                if let collapsedContent {
                    collapsedContent()
                } else {
                    subviews[0]
                }
            } else {
                Menu {
                    ForEach(subviews) { subview in
                        subview
                    }
                    .labelStyle(.titleAndIcon)
                } label: {
                    menuLabel()
                }
                .menuOrder(.fixed)
            }
        }
    }
#endif

}


/// A value offered by a selection menu. Disabled values are displayed but not selectable.
public struct SBJMenuChoice: Identifiable, Equatable {
    public let id: Int
    public let title: String
    public let isEnabled: Bool

    public init(id: Int, title: String, isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
    }
}

// Pure selection policy, shared by the view and its regression tests.
enum SBJMenuSelectionPolicy {
    static func isInvalid(selection: Int?, choices: [SBJMenuChoice], explicitInvalid: Bool) -> Bool {
        explicitInvalid || (selection != nil && !choices.contains { $0.id == selection })
    }

    static func showsMenu(selection: Int?, choices: [SBJMenuChoice], invalid: Bool) -> Bool {
        if choices.isEmpty && selection == nil && !invalid { return false }
        if choices.count == 1 && choices[0].id == selection && choices[0].isEnabled && !invalid { return false }
        if choices.allSatisfy({ !$0.isEnabled }) { return false }
        return true
    }
}

private extension SBJSelectionMenu {
    @ViewBuilder
    static func selectionBody(
        selection: Binding<Int?>,
        choices: [SBJMenuChoice],
        currentTitle: String,
        emptyTitle: String,
        invalidSelection: Bool
    ) -> some View {
        let invalid = SBJMenuSelectionPolicy.isInvalid(
            selection: selection.wrappedValue, choices: choices, explicitInvalid: invalidSelection
        )
        let title = currentTitle.isEmpty && choices.isEmpty ? emptyTitle : currentTitle
        Group {
            if !SBJMenuSelectionPolicy.showsMenu(
                selection: selection.wrappedValue, choices: choices, invalid: invalid
            ) {
                Button {} label: {
                    Text(choices.isEmpty && !invalid ? emptyTitle : title)
                }
                .disabled(true)
                .buttonStyle(.plain)
                .sbjActiveControl()
            } else {
                Menu {
                    ForEach(choices) { choice in
                        Button(choice.title) { selection.wrappedValue = choice.id }
                            .disabled(!choice.isEnabled)
                    }
                } label: {
                    SBJSelectionMenuLabel(text: title, options: choices.map(\.title))
                }
                .menuOrder(.fixed)
                .buttonStyle(.plain)
                .sbjActiveControl()
            }
        }
        .foregroundColor(invalid ? .red : .primary)
        .accessibilityValue(invalid ? "Invalid selection: \(title)" : title)
        .accessibilityHint(invalid ? "Current value is not among available choices" : "")
    }
}

public extension SBJSelectionMenu where Content == EmptyView {
    /// A binding-based convenience; unlike action menus, a single selected value
    /// is noninteractive and an invalid value remains visible.
    init(
        selection: Binding<Int?>,
        choices: [SBJMenuChoice],
        currentTitle: String,
        emptyTitle: String = "None available",
        invalidSelection: Bool = false
    ) {
        self.content = { EmptyView() }
        self.collapsedContent = nil
        self.menuLabel = { AnyView(EmptyView()) }
        self.selectionView = {
            AnyView(Self.selectionBody(
                selection: selection,
                choices: choices,
                currentTitle: currentTitle,
                emptyTitle: emptyTitle,
                invalidSelection: invalidSelection
            ))
        }
    }
}
