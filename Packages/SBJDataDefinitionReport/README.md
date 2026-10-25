# SBJDataDefinitionReport

Phase 9A provides an instance-free catalog of compiled structural declarations.
The package has no dependency on SBJStructuredEditor and does not create model instances.

Use `SBJDefinitionCatalog(Recipe.self)` for a single structured root. Use
`SBJDefinitionCatalog.Builder` to register multiple structs and enum definitions;
`add` has overloads for `SBJStructured`, `SBJEnumCaseIdentifiable`, and
`SBJStructuredEnum`. Build once to receive a deterministic, deduplicated catalog.

Type ordering is alphabetical by default. Property and case ordering preserve
source declaration order. All three are independently configurable.

The schema presently exposes stored structural properties, their actual Swift
identifiers and declared types, constraint and presentation hints, and PropertyInfo.
Associated-value enums expose payload names and types via typed metadata dispatch.

## Explicitly deferred until declaration metadata is extended

Automatic transitive discovery of referenced types, raw-value enum literals,
static/computed PropertyInfo-only declaration inventory, and fully qualified
references through Optional/collection wrappers are not available from current
DataDefinition type metadata. They are *not* inferred from constructed values.
These capabilities must be added to DataDefinition macro output before marking
Phase 9A complete. The report is PDF-only; there is no independent SwiftUI report layout.

## Native SBJLayout PDF output

On UIKit/PDFKit platforms, `SBJDefinitionPDFReport.makePDF(catalog:pageLayout:title:)`
returns PDF data without displaying a view. `makePDFResult` returns the SBJLayout
`PDFRenderResult` with a `PDFDocument` and `PaginationPosition` entries keyed
by `type-0`, `type-1`, etc. `SBJDefinitionReportView` (also available as `SBJDefinitionPDFReportView`) presents the document
using `PDFPresentationController` and `PDFPresentationView` from SBJLayout.

PDF content reflects **registered catalog metadata only**. Transitive discovery,
raw-value declarations, and annotated static/computed members remain subject
to the catalog's documented 9A limitations.

The report has no custom SwiftUI catalog views, navigation stacks, lists, or rows.
The only view is a thin SwiftUI host for SBJLayout’s `PDFPresentationView`;
all report content is rendered as a PDF by `PDFGenerator`.

```swift
let catalog = SBJDefinitionCatalog(MyModel.self)
let pdf = SBJDefinitionPDFReport.makePDF(catalog: catalog)
SBJDefinitionReportView(catalog: catalog) // displays generated PDF
```

## Source ownership

- `SBJDefinitionTransformation.swift` maps DataDefinition's compiled metadata into the nonrecursive report catalog.
- `SBJDefinitionPDFReport.swift` statically generates the PDF using SBJLayout renderables and PDFGenerator; it does not import SwiftUI.
- `SBJDefinitionReportView.swift` hosts only `PDFPresentationView`, a toolbar using `PDFPageControlView`, a PDF share action, and a DEBUG Recipe preview.

The share action exports the generated PDF to a temporary `.pdf` file. The viewer and static generator use the same catalog.

## Recursive report and toolbar sorting update

The catalog now follows `SBJStructured` references transitively, as well as
`SBJStructuredEnum` associated-value payload references and types wrapped by
`Optional`, `Array`, `Set`, and `Dictionary`. Recursion is deduplicated by type
identity to protect recursive models. The PDF viewer includes **Sort report**
with separate type, property, and enum case order selections. The live PDF and
share file are regenerated when an ordering selection changes.

This does **not** expose properties or enum cases that are not reported by the
underlying SBJDataDefinition metadata, and does not enumerate arbitrary
nonconforming types. For unsupported enum families, additional macro metadata
or explicit registration remains necessary.

## Property and enum-case descriptive information

The PDF renders `SBJPropertyInfo.summary`, `SBJPropertyInfo.details`, and
`SBJPropertyInfo.symbol` when present for each property and enum case. Long
descriptions wrap and paginate with the normal SBJLayout flow. Accessibility
metadata is deliberately omitted from the report.
