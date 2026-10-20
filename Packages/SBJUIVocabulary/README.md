# SBJUIVocabulary

A small, application-independent vocabulary of reusable UI controls and presentation primitives shared by SBJStructuredEditor and SBJLayout.

## Scope

The package is intentionally a **scaffold** at this stage. No existing UI implementation has moved into this module.

Intended initial scope, driven only by editor and layout dependencies:
- Appearance and essential presentation modifiers
- Reusable symbol buttons, menus, and field components
- Search field UI, not structural search logic
- The color/font value and platform UI adapters that are actually needed by those consumers

Do not move complete subsystems, application screens, domain workflows, or unrelated UI helpers merely because they are UI code. Preserve platform-independent Codable definitions and place platform-specific support in separate extension files when moved later.

The dependency direction is consumer → SBJUIVocabulary → lower-level packages; this package must never depend on SBJFoundation, SBJLayout, or SBJStructuredEditor.
