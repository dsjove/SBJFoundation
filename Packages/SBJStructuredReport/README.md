# SBJStructuredReport

`SBJStructuredReport` creates a **type-level report** from compiled `SBJStructure` declarations. It never initializes model instances and does not inspect the current values of a document. The catalog may be consumed independently of a PDF viewer.

## Dependencies and scope

The package depends on `SBJStructure`, `SBJLocalization`, `SBJLayout`, and `SBJUIVocabulary`. Sharing and PDF preview controls are provided by the merged `SBJUIVocabulary`; no `SBJSharing` package is required.

Use `SBJStructure` for structural descriptors and traversal, `SBJLocalization` for domain names and descriptions, and this package for **cataloging and presenting** the declarations. Report formatting and catalog sorting stay here, not in the foundational packages.

## Creating a catalog

```swift
import SBJStructure
import SBJStructuredReport

let catalog = SBJDefinitionCatalog(MyModel.self)
let alphabetized = catalog.sorted(using: .init(
    typeSort: .alphabetical,
    propertySort: .alphabetical,
    caseSort: .declaration
))
```

`MyModel` must conform to `SBJStructured`. For multiple entry points, use `SBJDefinitionCatalog.Builder` and call `add` for `SBJStructured`, `SBJStructuredEnum`, or `SBJEnumCaseIdentifiable` types before `build()`. The catalog deduplicates by Swift type identity and follows supported nested structural references through `Optional`, `Array`, `Set`, and `Dictionary`. Registration does not evaluate instance properties or computed getters.

The catalog exposes original Swift identifiers, reflected declared types, annotations, presentation hints, and nomenclature. Stored and computed declarations both use canonical metadata, including constraints, access capability and user-facing visibility. Computed setters can be writable; immutable and restricted-setter properties are read-only. Report includes presentation-excluded properties but not private or structurally excluded declarations. Catalog sorting is configurable separately for types, fields, and enum cases. Declaration order is preserved as metadata even when display sorting changes.

## Generating and presenting a PDF

On platforms with PDFKit and UIKit/AppKit:

```swift
let data = SBJDefinitionPDFReport.makePDF(catalog: catalog)
let result = SBJDefinitionPDFReport.makePDFResult(catalog: catalog)
// In a SwiftUI view:
SBJDefinitionReportView(catalog: catalog)
```

The pure catalog API does not need PDFKit. `makePDFResult` provides a `PDFRenderResult`, including page-relative section positions for `type-0`, `type-1`, etc. The SwiftUI view hosts `SBJLayout.PDFPresentationView`, with page settings, sorting, and a PDF share action. PDF generation and rendering are main-actor APIs.

The report only describes declarations made available by compiled structural metadata. It does **not** inspect live values, invent raw enum values, evaluate computed getters, or discover arbitrary unconforming types. Type display formatting strips the standard `Swift.` qualifier but retains other module qualifiers.

## Client considerations

- The PDF output and export are generated from the catalog snapshot; refresh the catalog if the report's root selection changes.
- Sorting the viewer regenerates its PDF; generating a PDF directly does not mutate catalog metadata.
- Page layout is stored in user preferences using the historical key `SBJDataDefinitionReport.pageLayout` to retain existing settings after the module rename.
- Share export files are created in the temporary directory. An application with unusually frequent export regeneration may want to manage temporary-file retention as part of its lifecycle.
- `SBJDefinition*` remains the API prefix for declaration metadata and reports. Only the **package/library/module** is renamed to `SBJStructuredReport` in this iteration.

## Organization

- `Catalog/` — registration, transitive discovery, ordering, and report type display.
- `PDF/` — PDF generation using `SBJLayout`.
- `Presentation/` — SwiftUI viewer and report-specific nomenclature/symbology.

See `Documentation/Refactoring-Iteration-4.md` for the coordinated migration and verification limits.

### Model traversal options

Pass `traversalOptions:` to `SBJDefinitionCatalog` or its `Builder` independently
of `SBJDefinitionCatalogOptions` (sorting) and PDF/view formatting. The default
`.definition` includes discoverable presentation-excluded declarations; `.all`
restricts the catalog to user-facing fields. Private and fileprivate fields are
never discoverable. Sorting an existing catalog preserves its traversal options.
