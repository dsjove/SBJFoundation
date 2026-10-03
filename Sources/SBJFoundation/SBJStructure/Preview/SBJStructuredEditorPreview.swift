#if !os(tvOS) && !os(watchOS)
  #if DEBUG
    import SwiftUI

    /// Full automatic-editor preview for the canonical `SBJStructureSampleModel`.
    /// The standalone `SBJEditField` preview edits this same model so manual and
    /// automatic composition remain visibly tied to one integration fixture.
    @MainActor
    private struct SBJStructuredEditorPreviewHost: View {
      @State private var value: SBJStructureSampleModel
      @State private var editorState = SBJEditorViewState()
      @State private var hasAppliedRegressionMutation = false
      private let regressionMutation: ((inout SBJStructureSampleModel) -> Void)?

      init(
        value: SBJStructureSampleModel = SBJStructureSampleModel(),
        regressionMutation: ((inout SBJStructureSampleModel) -> Void)? = nil
      ) {
        _value = State(initialValue: value)
        self.regressionMutation = regressionMutation
      }

      private var registry: SBJEditorRegistry {
        var registry = SBJEditorRegistry()
        registry.register(SBJStructureSampleRating.self) { label, binding, _ in
          HStack(spacing: 8) {
            Text(label)
            Stepper(
              value: Binding(
                get: { binding.wrappedValue.value },
                set: { binding.wrappedValue.value = min(5, max(0, $0)) }
              ),
              in: 0...5
            ) {
              Text(binding.wrappedValue.value.formatted())
            }
          }
        }
        return registry
      }

      var body: some View {
        VStack(alignment: .leading, spacing: 8) {
          VStack(alignment: .leading, spacing: 4) {
            Text("SBJStructure Sample Editor")
              .font(.headline)
            Text(
              "The canonical sample model is shared by this automatic editor, the standalone field preview, and integration tests."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
          }

          SBJEditorSearchView(value: value, state: $editorState, registry: registry)

          SBJEditorScrollView(state: $editorState) {
            SBJEditorView(value: $value, state: $editorState, registry: registry)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
          }
        }
        .onAppear {
          guard !hasAppliedRegressionMutation, let regressionMutation else { return }
          hasAppliedRegressionMutation = true
          regressionMutation(&value)
        }
      }
    }

    #Preview("SBJStructure Sample — Default") {
      SBJStructuredEditorPreviewHost()
        .padding()
        .frame(minWidth: 760, minHeight: 1_000)
    }

    #Preview("SBJStructure Sample — Large Type") {
      SBJStructuredEditorPreviewHost()
        .padding()
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(minWidth: 760, minHeight: 1_000)
    }

    #Preview("SBJStructure Sample — French") {
      SBJStructuredEditorPreviewHost()
        .padding()
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .frame(minWidth: 760, minHeight: 1_000)
    }

    #Preview("SBJStructure Sample — Right to Left") {
      SBJStructuredEditorPreviewHost()
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
        .frame(minWidth: 760, minHeight: 1_000)
    }

    // Increased Contrast, Differentiate Without Color, and Reduce Transparency
    // are read-only environment values on this target. Exercise those variants with
    // Xcode's Environment Overrides / Accessibility Inspector rather than attempting
    // to inject them with `.environment(...)`.

    #Preview("SBJStructure Sample — Dark") {
      SBJStructuredEditorPreviewHost()
        .padding()
        .preferredColorScheme(.dark)
        .frame(minWidth: 760, minHeight: 1_000)
    }

    #Preview("Regression — Narrow + AX5") {
      SBJStructuredEditorPreviewHost()
        .padding()
        .environment(\.dynamicTypeSize, .accessibility5)
        .frame(width: 390)
        .frame(minHeight: 1_000)
    }

    #Preview("Regression — German") {
      SBJStructuredEditorPreviewHost()
        .padding()
        .environment(\.locale, Locale(identifier: "de_DE"))
        .frame(minWidth: 760, minHeight: 1_000)
    }

    #Preview("Regression — Arabic RTL") {
      SBJStructuredEditorPreviewHost()
        .padding()
        .environment(\.locale, Locale(identifier: "ar_SA"))
        .environment(\.layoutDirection, .rightToLeft)
        .frame(minWidth: 760, minHeight: 1_000)
    }

    #Preview("Regression — Changed Empty Invalid") {
      SBJStructuredEditorPreviewHost(regressionMutation: { recipe in
        recipe.servings = 0
        recipe.notes = nil
        recipe.summary = ""
        recipe.ingredients[0].quantity = 2.75
        recipe.ingredients[0].preparation = nil
      })
      .padding()
      .frame(minWidth: 760, minHeight: 1_000)
    }
  #endif
#endif
