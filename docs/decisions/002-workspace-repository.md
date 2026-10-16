# Separate workspace repository

Status: accepted by Steve. Date: 2026-10-16.

## Problem and alternatives

Shared guidance and development tools sit outside the three application
repositories. Options were to move them into the web fork, create a separate
workspace repository with ignored checkouts, or use Git submodules.

## Decision and rationale

Use a separate repository named `biodiversity-surveys` for shared documentation,
engineering guidelines, cross-application decisions, and development scripts.
Keep `web`, `api`, and `mobile` as independent, ignored checkouts. This preserves
their upstream histories and allows each application to evolve independently
without introducing submodule maintenance.

## Consequences

Clone the applications separately and commit changes within the owning repository.
Keep application-specific documentation and decisions with their implementation;
link to those records from the shared index instead of maintaining duplicates.
The workspace does not pin application revisions. Setup documentation identifies
the current web development branch, which may evolve.

Ignore local runtimes, credentials, downloaded reference data, backups, and output.
Track the authored reference-data README as an explicit exception. Derive the
workspace location in setup scripts; the local directory need not be renamed.
