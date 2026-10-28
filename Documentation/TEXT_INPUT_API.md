# Text input presentation API

`SBJStringPresentationValue` is defined by SBJDataDefinition and contains portable
text input configuration. In SBJUIVocabulary, apply the input policies through
`.sbjTextInput(presentation)` on an existing text control. This modifier does **not**
choose a control type, create a sheet, or apply layout.

- Use `.sbjSingleLineField()` (or its focus-binding overloads) for single-line
  field layout and chrome. The former `.oneLiner()` spelling is removed.
- Use `.sbjMultilineField(isFocused:minHeight:)` for multiline editor chrome.
- Apply `.sbjTextInput(presentation)` to either control when input policies matter.
- `PlaceholderMultilineTextField` accepts an optional `presentation:` value and
  applies it consistently to inline and sheet editors.

The preceding `sbjApplyTextInputPolicies(autocorrection:capitalization:)`
entry point is removed. Editing workflow and focus policy remain owned by
higher-level controls.
