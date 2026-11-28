# Structured assistant playground

A macOS Xcode playground for the canonical `SBJStructureSampleModel` recipe.
It uses the public assistant factory, lifecycle and SwiftUI presentation APIs.
There is no dependency on Jove's Characters or SBJStructuredEditor.

## Open and run

1. Keep this directory inside `Packages/SBJStructuredAI`, with the normal sibling packages available.
2. Open `SBJAssistant.xcworkspace` in Xcode. Select the `SBJStructuredAI` package scheme and My Mac. Use the Debug build configuration: the canonical sample model is compiled only under `DEBUG`.
3. Build the scheme. Open `SBJAssistant.playground` from the workspace and confirm **Build Active Scheme** is enabled in the File inspector. Run the playground and display the live view.
4. If Xcode does not recognize the package reference, add the parent `SBJStructuredAI` package folder to the workspace using File > Add Files. Do not add duplicate package references. The playground must be in the same workspace as the active package scheme.

The native assistant requires the same OS, hardware, and Apple Intelligence availability as the package. Unsupported platforms show the existing availability view. Xcode package linkage, live view execution, and native inference require verification on Apple hardware.

## Exercise the prototype

The left pane displays the committed recipe through the existing Swift source encoder and its revision. The right pane is the standard assistant view, including its approval panel, diagnostics, share and reset controls. Persistence is in-memory only; the revision increments on an approved, successful write. Rejection does not alter the recipe.

Try these in separate turns (the current prototype permits one reviewed write per turn):

| Prompt | Expected behavior |
| --- | --- |
| How many servings does the recipe make? | Read 4 initially. |
| List the ingredients. | Read collection keys/values. |
| Describe the servings field. | Read constraints (1–24). |
| Change servings to 6. | Approval, then revision increment and new value. |
| Change servings to 0. | Validation rejects the change. |
| How many ingredients are there? | Count without approval. |
| Add the tag Quick. | Collection proposal. |
| Remove the tag Quick. | Collection proposal. |
| Move the last ingredient to the first position. | Collection move proposal. |
| Add a new ingredient. | Attempt default creation; then edit its fields in later turns. |
| Find the step whose instruction contains al dente. | Content selection. |

These are intended smoke tests, not guaranteed language-model outcomes. Context capacity may prevent a session from starting even with the sample; use the model configuration controls to reduce the exposed definition and inspect the assistant diagnostics. Applying a different configuration creates a fresh assistant session without changing the recipe or its revision. Turning off editing registers the read-only tool set. Reset Assistant clears the conversation, not the model. Restore sample replaces the in-memory recipe and advances the revision.

The playground owns document state and checks the document ID/revision before committing. It does not implement its own mutation engine, validation, approval panel or native tools.

Apple reference: https://developer.apple.com/documentation/xcode-release-notes/xcode-12-release-notes/ (Build Active Scheme for playground package imports).
