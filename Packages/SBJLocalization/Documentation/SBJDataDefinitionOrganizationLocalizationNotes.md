# SBJDataDefinition — Organization localization-related notes

# Package organization and dependencies

`SBJDataDefinition` depends on `SBJLocalization` for nomenclature and text search. It does not import SwiftUI or depend on `SBJStructuredEditor`. The editor consumes structural metadata to implement views, bindings, navigation, and disclosure. `SBJPropertyInfo` is defined in SBJLocalization.

