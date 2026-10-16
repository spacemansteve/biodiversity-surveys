# Shared project instructions

This is the biodiversity-surveys shared workspace for extending iNaturalist with
structured biodiversity surveys. The `web`, `api`, and `mobile` directories
contain separate upstream repositories and are ignored by the workspace Git
repository. Commit application changes in their own repositories.

Before planning or changing iNaturalist Survey functionality, read and follow
[Engineering Guidelines for Extending iNaturalist with Survey Support](docs/engineering/inaturalist-survey-guidelines.md).
These are standing project guidelines across all three repositories. Also read
any applicable instructions within the repository being changed.

Study before changing. Reuse before creating. Extend before replacing. Preserve
before refactoring. Investigate existing Trips first, preserve observations and
iNaturalist taxonomy, and keep changes small and compatible with upstream.

Follow the document's requirements to present alternatives before consequential
architectural changes and obtain explicit approval for the changes listed in
section 37. Record consequential decisions under `docs/decisions/` as described
in the documentation index; chat history alone is not a decision log.

See [Project documentation](docs/README.md) for shared guidelines and where to
add future documents.
