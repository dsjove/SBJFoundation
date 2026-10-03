# SBJFoundation Testing

SBJFoundation is a low-level dependency for multiple applications, so its tests should protect
stable semantics and regression-prone infrastructure rather than duplicate SwiftUI implementation
details.

## Two complementary coverage mechanisms

### SBJStructure sample compile coverage

`SBJStructureSampleModel` is the canonical integration fixture used by both editor previews and
by focused integration tests. It declares every SBJStructure annotation and intentionally pulls
the editor dependency graph into one living sample. Its contract is documented in
[`SAMPLE_COVERAGE.md`](../Sources/SBJFoundation/SBJStructure/Documentation/SAMPLE_COVERAGE.md).

This is compile dependency coverage: if a type on that path is removed, the Preview should no
longer build. It is not runtime branch coverage.

### Focused tests

Focused tests protect behavior that a compile fixture cannot:

- macro expansion and structural metadata;
- structural equality/content/default/validation semantics;
- collection mutation and editor traversal/identity;
- Swift source encoding;
- Codable platform-value bridges;
- accessibility/localization mechanics and semantic wiring (not exact copy);
- reusable UI API surfaces and pure presentation policies;
- help content-type resolution, presenter dispatch, compatibility conventions, and cross-platform compile seams;
- shared workflow seams that were consolidated from retired packages.

## Refactoring gaps reviewed during the SBJFoundation rename

The recent consolidation introduced several behaviors that deserved explicit regression tests:

1. **Observation without a context object** — the original helper once failed to re-arm this
   path after a change. `ObservationTests` now verifies repeated context-free delivery and
   synchronous cancellation.
2. **Free-form one-line editor width** — unconstrained String fields should fill the available
   horizontal space, while constrained strings remain intrinsic. `SBJFieldWidthPolicyTests`
   protects that policy without snapshot-testing SwiftUI layout.
3. **Presentation-resource concurrency** — `ImageReference` is an immutable image description
   and must remain `Sendable`. `ImageReferenceTests` now enforces that at
   compile time.
4. **Retired-package workflow ownership** — the unit conversion model/view now live in
   SBJFoundation. `UnitValueTests` protects conversion/swap/reset semantics and construction of the
   shared conversion views.

Existing tests already cover the major structural/editor/codable behaviors touched by the recent
moves. No additional snapshot/UI-rendering suite is recommended merely for directory or module
renames.

## Help coverage

`Help/SBJHelpTests.swift` protects the help framework at semantic seams rather than snapshotting
SwiftUI/WebKit output. It verifies `UTType` resolution and explicit override precedence,
asset-catalog and ordinary bundle-resource lookup, HTML/Markdown presenter dispatch, the bundled
SBJStructure editor topic, recursive embedded-help composition, shared help imagery, and
construction of `SBJHelpLink` on the active target. The latter is specifically intended to catch
accidental references to `SwiftUI.HelpLink` in iOS/Mac Catalyst compilation, where that Apple type
is unavailable.

When a new built-in help representation is added, add presenter-dispatch coverage and any pure
resolution behavior here. Do not duplicate Apple renderer behavior.

## What not to test here

- Apple framework behavior already guaranteed by SwiftUI/UIKit/Foundation.
- Pixel-perfect editor rendering; use previews and accessibility/manual regression checks.
- Exact user-facing copy, English wording, localization strings, or the concrete SF Symbol chosen for a semantic image. Those are intentionally changeable presentation decisions. Test semantic wiring/resource resolution instead.
- Every annotation parameter or enum case solely for coverage metrics.

When localization/presentation-resource resolution becomes implemented, add resolver tests at the
semantic boundary and measurement/fit tests in SBJLayout rather than forcing those into view
snapshots.
