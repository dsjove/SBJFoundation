# Testing guide

Tests should verify **meaningful behavior and externally observable contracts**. Prefer focused unit tests for validation, conversion, persistence, macro expansion, transformations and state transitions. Avoid tests that merely read a stored property, echo a string literal, or instantiate a type without exercising behavior.

## Run tests

Each nested package has its own `Package.swift`; SwiftPM runs package test targets independently. From a package directory, run `swift test` when the current platform supports that package. For SwiftUI targets, use Xcode with an appropriate Apple-platform test destination. The enclosing Foundation package and individual nested packages do not automatically form one umbrella test target.

## Package responsibilities

- **SBJDataDefinition:** generated structural members and annotations, validation, equality, defaults, traversal, collection changes and source encoding.
- **SBJLocalization:** string transformation rules, optional/empty presentation handling, accessibility behavior and metadata decisions. Do not test duplicated literal titles.
- **SBJUIVocabulary:** field-sizing and menu-selection policy, disabled/invalid decisions and meaningful UI state policy. Prefer pure policies over snapshots.
- **SBJUnits:** Codable round trips preserving unit choices, conversion mathematics, invariant checks and conversion-state workflow.
- **SBJFileResources:** content integrity, resource resolution, filename collision handling, security-scope and failure behavior.
- **SBJDocuments:** document/library persistence behavior, ordering and error recovery.
- **SBJHelp:** content resolution, templating precedence and presenter dispatch; do not retest Foundation's string replacement.
- **SBJCamera:** encoded capture representation and capture behavior; avoid tests limited to stored properties.
- **SBJStructuredEditor:** tests its own parsing, structural projection, model-driven editing, validation propagation, traversal, and nontrivial state transitions.
- **SBJFoundation:** integrated image/attachment/structured-editor interactions and platform behavior not owned by the smaller modules.

## Editor integration

The editor's sample model and preview give **compile coverage** of the annotation and dependency graph; they do not substitute for behavioral tests. Preserve tests for mutation, validation, navigation, selection, filtering and state restoration. Do not test SwiftUI rendering, focus mechanics, or simple modifier behavior. Verify meaningful behavior at pure-model and editor-integration boundaries.

## Do not add tests for

- Plain getters, setters, initializers or computed properties with no behavior.
- Direct string copies, or assertions that documentation strings equal their literals.
- `#expect(true)` and tests that only prove the test target loads.
- One-to-one forwarding that is already adequately tested at its behavioral boundary.

When a simple implementation is part of a **serialization or public compatibility contract**, test the contract rather than the mechanical accessor. Test names should describe the requirement they protect.
