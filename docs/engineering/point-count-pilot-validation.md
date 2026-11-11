# Point-count pilot validation — October 25, 2026

## Baseline and data preservation

Before changes, the isolated survey suite passed 45 examples. The upstream Trip,
TripTaxon and TripPurpose specs passed 14 examples, with no failures and two
pre-existing pending examples. They ran against `inaturalist_survey_v02_test`.
No production services were involved.

The populated candidate database was backed up before applying its five pending
survey migrations:

- Database: `inaturalist_survey_candidate_20261014`
- Backup: `resources/inaturalist/backups/candidate-before-point-count-20261025.dump`
- SHA-256: `56e4aa9b59d5582498e66aef042ad8aa5d8b678b64274a8ab480abbd03b353ff`
- `pg_dump -Fc` and `pg_restore --list` succeeded. This new backup has not been
  restore-tested; the earlier baseline backup's restore verification is documented
  separately in the database load record.
- Applied migrations `20261015000001` through `20261015000005`; no additional
  schema migration was required for the point-count workflow.
- Taxonomy count after migration: 1,668,467, unchanged. Existing local account:
  `steve`, ID 1. No synthetic development observations or survey events were created.

Installed Stationary Bird Point Count v1 through `surveys:install_point_count`,
owned by the existing local account. The installer publishes a new protocol and
its typed measurement definitions, not a visit or an observation.

## Verification of the new workflow

Run from `web` after sourcing the workspace environment:

```bash
RAILS_ENV=test \
DATABASE_URL=postgis://inaturalist:inaturalist@127.0.0.1/inaturalist_survey_v02_test \
bundle exec rspec spec/surveys/*_spec.rb
```

Result: **65 examples, 0 failures**, including the original 45 examples and 20
new protocol/HTTP examples. Coverage includes zero detections, partial effort,
separate compliance and reporting assessments, immutable protocol installation,
repeat station visits, bird taxonomy, count validation, evidence ownership,
transaction rollback, owner-only reads/writes, ignored privilege parameters,
no JSON exposure, CSRF rejection even with an Authorization header, completed
record freezing, and void history. HTTP tests render the real templates through
Rails middleware with the existing Devise integration helpers.

Static validation: all eight new Ruby/Rake/test files passed RuboCop without
offenses. Both repositories passed `git diff --check`. API and mobile working
trees remain clean.

The request tests emit existing Rack::Tracker warnings about unconfigured IDs.
The pilot controller skips tracker configuration and its layout loads no analytics.
No tests were disabled to suppress the warnings. The entire unrelated application
suite was not run.

## Running environment

Rails and the existing API were started using `bin/start-web` and `bin/start-api`.
Verified responses:

- Unauthenticated `/point_counts`: redirects to normal sign-in.
- Existing Rails `/taxa/54779`: HTTP 200.
- API `/v1/taxa/48460`: HTTP 200.
- Safari's existing `steve` session can access `/point_counts` and the new-station
  form at `/point_counts/new`.

PostgreSQL, Redis, Memcached, Elasticsearch and Qdrant were already running.
Elasticsearch has one data node, all 78 primary shards active and 78 unassigned
shards; yellow health is consistent with unavailable replicas on a single node.
No replica settings or existing indexes were changed.

See the local application document
`web/docs/protocols/stationary-bird-point-count-v1.md` for the approved protocol,
workflow and remaining production-policy limits. Root documentation and web code
belong in their respective Git repositories; publish the web changes before publishing the shared documentation links.

## November 10 pre-commit check

After adding the signed-in **My surveys** menu link and changing the pilot's
referrer policy to `same-origin`, the complete survey suite passed **66 examples
with no failures**. The new request test checks that a valid form submitted from
its own origin succeeds while null and foreign origins are rejected. Rails CSRF
token and origin checks remain enabled. RuboCop reported no offenses across the
eight pilot Ruby, task and test files.
