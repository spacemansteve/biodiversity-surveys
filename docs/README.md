# Project documentation

Shared biodiversity-surveys documentation for iNaturalist Survey work across
`web`, `api`, and `mobile`.

## Engineering guidelines

Keep standing engineering guidance in `engineering/`, using descriptive,
lowercase, hyphen-separated Markdown filenames. Add new documents to this index.

- [Engineering Guidelines for Extending iNaturalist with Survey Support](engineering/inaturalist-survey-guidelines.md)
  — supplied by Steve on October 14, 2026; preserved verbatim. Read before
  planning or implementing Survey changes.

## Development setup plans

- [Local application cutover](engineering/application-cutover.md)
  — current database/index selection, verified URLs, and rollback.

- [Development database initialization](engineering/development-database-initialization.md)
  — official data downloads, local database findings, and proposed initialization.
- [Candidate database load record](engineering/development-database-load-record.md)
  — executed import, backup, source exceptions, and validation results.

## Architectural decisions

Add consequential decisions under `decisions/` when they are made, with names
such as `001-survey-representation.md`. Include status (including whether a
decision is provisional), date, problem, alternatives, decision, rationale,
and consequences.

- [Survey backend v0.2](decisions/001-survey-backend-v02.md)
  — composition with Trips, immutable scientific history, concurrency, privacy,
  deletion and testing decisions.

- [Separate workspace repository](decisions/002-workspace-repository.md)
  — repository boundaries, documentation ownership, and local artifacts.

## Survey backend

- [Schema and lifecycle](https://github.com/spacemansteve/inaturalist/blob/feature/survey-schema-v0.2/docs/survey_schema.md)
  — tables, supported protocol configuration, integrity rules and deferred policy.
- [Implementation report](https://github.com/spacemansteve/inaturalist/blob/feature/survey-schema-v0.2/docs/survey_implementation_report.md)
  — migrations, test commands/results, compatibility and scope.

Keep guidelines separate from decisions: guidelines describe how we work;
decision records explain specific architectural choices.

Application-specific documentation and decisions live with their application code.
The links above point to the web fork; local copies are under `web/docs/`.
