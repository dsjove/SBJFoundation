# SBJHelp ownership

- `SBJHelpTrigger`, `SBJHelpLink`, `SBJHelpButton`, `SBJHelpSheet`: Help UI and first-use presentation.
- `SBJHelpTemplateRenderer`: token and embedded-help expansion.
- `SBJHelpConfiguration`: caller-provided app identity, semantic images, and resource references.
- `SBJBundledContentReference.help`: generic Help resource reference constructor.
- URL opening lives in `SBJFileResources`; Foundation-specific `AppInfo` and HTML page references stay in Foundation.
- Use the native `UserDefaults` API for first-use history. The app controls its resources and may configure substitutions.
