# SBJDataDefinition — StructuralModelGuide localization-related notes

## Search and filtering

`SBJStructuralSearchMatcher` searches structured values. `SBJStructuralSearchAtomic` marks types whose meaningful textual representation should be searched without recursive reflection. `SBJStructuralSearchCriteria` combines text queries with changed-only and empty-content filters. Text matching delegates to SBJLocalization. Search results are independent of any view's disclosure state.

