# Field sizing (provisional organization)

These files are grouped here because they collectively implement preferred
widths for editable controls. The folder grouping is organizational only; no
behavior or access levels have changed.

- `SBJFieldSizing`: minimum, ideal and maximum nominal width preferences.
- `SBJNumericFieldSizing`: numeric range / locale-based width heuristics.
- `SBJTextFieldSizing`: maximum-length-based width heuristics.
- `SBJPreferredFieldWidthModifier`: Dynamic Type scaling and frame application.

## TODO: revisit the design

- Replace hard-coded widths, length tiers and per-character multipliers with
  font-aware measurement, including localized digits and formatting.
- Distinguish intrinsic text size, editable input affordance/padding, available
  container size, and domain constraints.
- Confirm the font and Dynamic Type used for measurement match the rendering font.
- Investigate a shared text measurement service that can use `CodableFontCache`
  to obtain realized fonts and optionally cache measured runs. Cache keys must
  account for actual text, effective font/scale, wrapping and layout constraints;
  consider invalidation and unbounded cache growth.
- Preserve the separation between localization resource resolution, selecting
  a candidate that fits, and sizing an editable field. Share measurement code
  where sensible, but do not collapse these responsibilities together.
- Reconsider whether the helpers should live with editor controls versus a
  shared layout/measurement package once real non-editor consumers are known.

No heuristic replacements are implemented as part of this organization pass.
