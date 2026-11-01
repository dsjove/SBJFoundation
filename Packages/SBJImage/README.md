# SBJImage

`SBJImage` handles image selection, references, non-destructive image documents, image geometry, editing, viewing, and import/export. Use it for user-facing image workflows rather than generic file storage or raw camera capture.

## Getting started

```swift
import SBJImage
```

Start with the photo menu or library surfaces when users need to choose an image; use the image editor when the workflow needs adjustments, and image document types when edits must be preserved non-destructively. Keep camera capture (`SBJCamera`) separate from editing and resource persistence (`SBJFileResources`). The feature owning the image decides how to store or reference the result.

