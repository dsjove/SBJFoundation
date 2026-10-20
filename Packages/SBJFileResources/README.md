# SBJFileResources

File and URL operations that can be used independently of document storage and UI.

## Use

```swift
import SBJFileResources
```

Features include `SBJResourceContent`, checked `FileWrapper` operations, filename sanitization and uniqueness, security-scoped URL access, bundled-content references and bundle resource lookup. The module also provides platform-aware URL validation/opening used by `SBJURLButton`; it is not interchangeable with SwiftUI's `openURL` environment.

## Boundaries

For document storage use `SBJDocuments`; for document-specific presentation use the owning UI module. This package has no local SBJ package dependencies.

## Tests

Focus on invalid paths, security-scope lifetimes, filename collisions, malformed resource data and error propagation rather than copies of filename text or trivial accessors.
