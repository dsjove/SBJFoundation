#if !os(tvOS) && !os(watchOS)
import SwiftUI

private struct SBJEditorPropertyInfoInlineKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SBJEditorPropertyInfoHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Places a property info button in normal layout flow rather than overlaying
    /// the property content. Used when a promoted title editor shares its parent
    /// row with trailing element actions such as reorder buttons.
    var sbjEditorPropertyInfoInline: Bool {
        get { self[SBJEditorPropertyInfoInlineKey.self] }
        set { self[SBJEditorPropertyInfoInlineKey.self] = newValue }
    }

    /// Suppresses the property's own info button when a parent row promotes that
    /// button into the row's shared trailing info gutter.
    var sbjEditorPropertyInfoHidden: Bool {
        get { self[SBJEditorPropertyInfoHiddenKey.self] }
        set { self[SBJEditorPropertyInfoHiddenKey.self] = newValue }
    }
}

@MainActor
struct SBJEditorPropertyInfoContainer: View {
    let content: AnyView
    let propertyName: String
    let info: SBJPropertyInfo?
    @Environment(\.sbjEditorRowLayoutSuppressed) private var rowLayoutSuppressed
    @Environment(\.sbjEditorRowEmbedded) private var rowEmbedded
    @Environment(\.sbjEditorPropertyInfoInline) private var propertyInfoInline
    @Environment(\.sbjEditorPropertyInfoHidden) private var propertyInfoHidden

    var body: some View {
        Group {
            if propertyInfoHidden {
                if let info {
                    accessible(content, using: info)
                } else {
                    content
                }
            } else if propertyInfoInline, let info {
                HStack(spacing: SBJEditorRowMetrics.laneSpacing) {
                    accessible(content, using: info)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    SBJEditorPropertyInfoButton(propertyName: propertyName, info: info)
                        .frame(width: SBJEditorRowMetrics.infoLaneWidth, alignment: .center)
                        .frame(minHeight: SBJEditorRowMetrics.firstLineMinimumHeight, alignment: .center)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Property info is normally a global trailing gutter, not a wrapper
                // column. Keeping it as an overlay prevents nested structured editors
                // from losing an info-button lane at every depth.
                Group {
                    if let info {
                        accessible(content, using: info)
                    } else {
                        content
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    if let info {
                        SBJEditorPropertyInfoButton(propertyName: propertyName, info: info)
                            .frame(width: SBJEditorRowMetrics.infoLaneWidth, alignment: .center)
                            .frame(minHeight: SBJEditorRowMetrics.firstLineMinimumHeight, alignment: .center)
                            .offset(
                                x: (rowLayoutSuppressed || rowEmbedded)
                                    ? SBJEditorRowMetrics.infoLaneWidth + SBJEditorRowMetrics.laneSpacing
                                    : 0
                            )
                    }
                }
            }
        }
    }

    private func accessible(_ view: AnyView, using info: SBJPropertyInfo) -> AnyView {
        AnyView(view.accessibility(info))
    }
}

@MainActor
struct SBJEditorPropertyInfoButton: View {
    let propertyName: String
    let info: SBJPropertyInfo
    @State private var isPresented = false

    private var title: String {
        info.title ?? propertyName
    }

    var body: some View {
        SBJImageButton(
            SBJSemanticImageReference.information,
            accessibilityLabel: info.accessibilityLabel ?? "Information about \(title)",
            accessibilityHint: info.accessibilityHint ?? info.summary
        ) {
            isPresented = true
        }
#if os(iOS)
        .popover(isPresented: $isPresented) {
            SBJEditorPropertyInfoSheet(
                title: title,
                info: info,
                showsDoneButton: false
            ) {
                isPresented = false
            }
            .presentationCompactAdaptation(.popover)
        }
#else
        .sheet(isPresented: $isPresented) {
            SBJEditorPropertyInfoSheet(
                title: title,
                info: info,
                showsDoneButton: true
            ) {
                isPresented = false
            }
        }
#endif
    }
}

@MainActor
private struct SBJEditorPropertyInfoSheet: View {
    let title: String
    let info: SBJPropertyInfo
    let showsDoneButton: Bool
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title2.weight(.semibold))
                if showsDoneButton {
                    Spacer(minLength: 12)
                    Button("Done", action: dismiss)
                }
            }

            Text(info.summary)
                .font(.headline)

            ScrollView {
                Text(info.details)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(idealWidth: 440, maxWidth: 520, idealHeight: 320, maxHeight: 520)
    }
}
#endif
