#if !os(tvOS) && !os(watchOS)
  #if DEBUG
    import SwiftUI

    /// Standalone-field coverage using the same canonical model as the automatic
    /// structured-editor preview. This intentionally exercises both `Binding<Value>`
    /// and model-aware `root:keyPath:` construction.
    @MainActor
    private struct SBJEditFieldPreviewHost: View {
      @State private var model = SBJStructureSampleModel()

      private var registry: SBJEditorRegistry {
        var registry = SBJEditorRegistry()
        registry.register(SBJStructureSampleRating.self) { label, value, _ in
          HStack {
            Text(label)
            Spacer()
            Stepper(
              value: Binding(
                get: { value.wrappedValue.value },
                set: { value.wrappedValue.value = $0 }
              ),
              in: 0...5
            ) {
              Text(value.wrappedValue.value.formatted())
            }
          }
        }
        return registry
      }

      var body: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            Group {
              Text("Text").font(.headline)
              SBJEditField("String", value: $model.name)
              SBJEditField("Multiline String", value: $model.summary, textStyle: .multiline)
              SBJEditField(
                "Sheet-edit String", value: $model.editorSheetText, textStyle: .sheetEdit)
              SBJEditField(
                "Font Family", value: $model.recipeCardFontFamily, presentation: .fontFamily)
            }

            Group {
              Text("Numbers and Boolean").font(.headline)
              SBJEditField("Bool", value: $model.vegetarian)
              SBJEditField("Int", value: $model.servings, integerRange: 0...100)
              SBJEditField("Int8", value: $model.editorInt8)
              SBJEditField("Int16", value: $model.editorInt16)
              SBJEditField("Int32", value: $model.editorInt32)
              SBJEditField("Int64", value: $model.editorInt64)
              SBJEditField("UInt", value: $model.editorUInt)
              SBJEditField("UInt8", value: $model.editorUInt8)
              SBJEditField("UInt16", value: $model.editorUInt16)
              SBJEditField("UInt32", value: $model.editorUInt32)
              SBJEditField("UInt64", value: $model.editorUInt64)
              SBJEditField("Double", value: $model.nutrition.proteinGrams, numberRange: 0...200)
              SBJEditField("Float", value: $model.editorFloat)
              SBJEditField("CGFloat", value: $model.editorCGFloat)
              SBJEditField("Decimal", value: $model.editorDecimal)
            }

            Group {
              Text("Foundation and SBJFoundation Leaves").font(.headline)
              SBJEditField("Date", value: $model.editorDate)
              SBJEditField("URL", value: $model.editorURL)
              SBJEditField("UUID", value: $model.identifier)
              SBJEditField("Data", value: $model.importFingerprint)
              SBJEditField("Color", value: $model.recipeCardTint, colorSupportsAlpha: false)
              SBJEditField("Unit Value", value: $model.servingVolume)
            }

            Group {
              Text("Recursive Editors").font(.headline)
              SBJEditField("Optional", value: $model.notes)
              SBJEditField("Array", value: $model.ingredients)
              SBJEditField("Set", value: $model.tags)
              SBJEditField("Dictionary", value: $model.substitutions)
              SBJEditField("CaseIterable", value: $model.course)
              SBJEditField("Associated Enum", value: $model.heatSetting)
              SBJEditField("Structured Value", value: $model.nutrition)
            }

            Group {
              Text("Model-aware Fields").font(.headline)
              SBJEditField(root: $model, keyPath: \.summary)
              SBJEditField(root: $model, keyPath: \.servings)
              SBJEditField(root: $model, keyPath: \.importFingerprint)
            }

            Group {
              Text("Registry Override").font(.headline)
              SBJEditField("Custom Value", value: $model.rating, registry: registry)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
        }
      }
    }

    #Preview("SBJEditField — All Supported Types") {
      SBJEditFieldPreviewHost()
        .frame(minWidth: 760, minHeight: 1_000)
    }
  #endif
#endif
