# Component responsibilities

`SBJHelp` deliberately separates three client-facing concerns:

- **Configuration:** `SBJHelpConfiguration`, `SBJHelpSymbology` and `SBJHelpNomenclature` provide help-specific defaults and application-supplied vocabularies; underlying semantic types belong to `SBJLocalization`.
- **Content:** `SBJHelpTemplateRenderer` composes bundled resources, literal replacements, semantic nomenclature, image tokens, and the shared stylesheet. Source content references belong to `SBJFileResources`.
- **Presentation:** `SBJHelpTrigger` manages one-time presentation and sheet state, `SBJHelpLink` and `SBJHelpButton` provide alternative native control shapes, `SBJHelpSheet` manages shared navigation and About, and content presenters render the resolved source.

Clients can override presentation using `SBJHelpContentPresenter` without changing the content resolution pipeline. HTML uses WebKit where available; the native Markdown presenter has newer platform requirements.

No structure-specific behavior is introduced. General domain nomenclature stays in `SBJLocalization`; file URLs and resource lookup stay in `SBJFileResources`.
