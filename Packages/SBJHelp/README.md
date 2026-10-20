# SBJHelp

Reusable help presentation, bundled-content references and template rendering for SwiftUI applications.

## Use

```swift
import SBJHelp
```

Configure `SBJHelpConfiguration` with the application's bundled resources and template substitutions. Help content remains with its owning feature or application; the help system provides rendering and resource resolution rather than owning every application's HTML.

See [Help architecture](Documentation/Architecture.md) and [Help system](Documentation/Help-System.md) for configuration and presentation details.

## Dependencies

`SBJFileResources` and `SBJLocalization`.

## Tests

Protect resource selection, substitution precedence, supported content-type dispatch, and error paths. Avoid asserting trivial literal replacements already guaranteed by Foundation's string APIs.

## Editor help

The structured editor owns its own help HTML. The editor exposes bundled-content references and `SBJHelpConfiguration.includeStructuredEditorHelp()` for applications that embed its help content. `SBJHelp` provides the presentation mechanism; it does not own those documents.
