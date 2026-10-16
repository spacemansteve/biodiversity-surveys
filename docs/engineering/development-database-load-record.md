# Candidate database load record — October 14, 2026

Update: full indexing and [application cutover](application-cutover.md) have since
completed. The record below describes the earlier database-loading phase.

Scope: back up the original local database, create a separate candidate, load
production taxonomy IDs and ancestry, scientific names, iconic relationships,
annotation vocabulary, and country places. Application cutover, full search
indexing, test users and observations are separate subsequent steps.

## Backup and isolation

Final validation passed: 1,668,467 taxa, 1,668,467 scientific names, 13 iconic
taxa, 40 controlled terms/values, 34 attribute/value links, 40 English labels,
130 taxonomic restrictions, and 242 country places with geometry and checklists.
There are zero source mismatches, missing scientific names, orphan names,
orphan term restrictions, invalid geometries, or places missing geometry/checklists.
Production term IDs, UUIDs, labels, restrictions, and value links were compared
against the saved API response. ID sequences and representative Rails model
validation/ancestry reads passed.

The original database was checked again: 70 taxa, 11 controlled terms, no users,
observations, or places, and its original Life/Animalia IDs remain 1/2.

- Original: `inaturalist_development`.
- Candidate: `inaturalist_survey_candidate_20261014`.
- Candidate Elasticsearch prefix: `survey_candidate_20261014`.
- Backup: `resources/inaturalist/backups/inaturalist_development-before-survey-20261014.dump`.
- Backup SHA-256: `2c88a70485837e1e06939a13e8480f9e8403a7f3723b0ae221e87456b76190e4`.
- Web commit: `355e40711e444f7b0c94c70fa160f8b2acdfe971`.
- API commit: `3351dd6ef0b3986722c017ba9264e093b53e5bc9`.

The custom-format backup was listed and completely decoded with `pg_restore`.
Its schema and migration metadata were restored into a new database created from
`template0`. Rails confirmed no pending migrations. No existing database was
reset, and no application database configuration was changed.

## Import method and source exceptions

The importer first created a five-taxon ancestor chain using normal Rails
validations and callbacks in a rolled-back transaction. Scientific names and
iconic relationships matched the intended bulk representation.

The full snapshot was then loaded as a database restoration, using PostgreSQL
COPY into a staging table and transactional inserts into the empty application
tables. This avoids millions of callbacks and preserves historical records that
would not pass today's create-record validations. No model validations or
application code were modified or disabled.

Source exceptions were preserved, not repaired:

- 32 inactive taxa have missing rank levels and historical rank labels.
- 536 rows have a parent rank that is not strictly coarser.
- 14 active taxa have an inactive immediate parent.
- 8 ancestry paths differ from the immediate parent's ancestry.

Every referenced ancestor exists. No self-ancestry, repeated ancestor IDs, or
cycles in immediate-parent links were found. These source inconsistencies can
make a subset of rows fail current model validation when edited; they are not
newly invented taxonomic relationships. The six-column export omits additional
curatorial flags and history, so this remains a development replica rather than
a full reproduction of production taxonomy behavior.

For bulk taxonomy, the importer reconstructs scientific `TaxonName` records,
lexicon/parameterized lexicon, source references, iconic flags and nearest iconic
ancestors, local UUID defaults, and sequences. Timestamps represent import time,
not original taxon creation time. There are no observations, identifications,
photos, or taxon frameworks to update. Wikipedia jobs, audit histories, and
production curation metadata are not fabricated. Full search indexing is deferred.

The controlled-term importer uses normal models, preserves production term IDs
and UUIDs, builds English labels and attribute/value links, and resolves taxonomic
restrictions by exact ID. Here “annotations” means annotation vocabulary; no
observation annotations are created without observations.

Country places use upstream `Place.new_from_shape` and normal model/geometry
callbacks. They retain Natural Earth source attribution and receive local IDs.
Country features include territories according to the source dataset; they are
not a copy of production iNaturalist Places. Country checklists are initially empty.

Geometry validation follows this application's SRID 0 column convention while
checking WGS84 longitude/latitude bounds, validity, and nonempty polygons. An
initial validator incorrectly expected SRID 4326; it was corrected to match the
existing schema without changing any geometry data.
The reference loader was then rerun successfully against the populated database;
counts remained unchanged, confirming it did not duplicate terms or countries.
The first run's optional place-index callbacks attempted to reach the stopped
local API for observation counts. Future runs defer those callbacks with the
existing `skip_indexing` flag; full candidate search setup remains a later step.

## Scripts and evidence

Workspace scripts are under `bin/development/`:

- `prepare-taxonomy.py`: verifies source checksums, inspects hierarchy, generates COPY input.
- `import-candidate-taxonomy.rb`: refuses any other database or a nonempty taxonomy,
  exercises model callbacks, loads the snapshot and names, and verifies source equality.
- `import-candidate-references.rb`: loads saved controlled terms and country shapes.
- `validate-candidate.rb`: verifies source equality, names, references, geometry,
  sequences, and representative model reads/validation; writes `result.json`.

Run Ruby scripts from `web` with the workspace toolchain and both environment
variables set explicitly:

```bash
source ./env.sh
cd web
DATABASE_URL=postgis://inaturalist:inaturalist@localhost/inaturalist_survey_candidate_20261014 \
INAT_ES_INDEX_PREFIX=survey_candidate_20261014 \
bundle exec rails runner ../bin/development/validate-candidate.rb
```

This uses the existing local development credentials. Do not start a candidate
application or worker without its isolated search prefix. Normal reference-data
callbacks can enqueue candidate-only background jobs; no worker was started by
this initialization.

Evidence is stored in `resources/inaturalist/2026-10-14/initialization/`:
`preflight.json`, `taxa-copy.tsv`, `taxonomy-import.log`, `reference-import.log`,
and the final validation report `result.json`. The staging table
`survey_taxa_import` is retained for comparison. It is local import bookkeeping,
not an application schema migration or a proposed upstream model.
`execution-manifest.json` records script and backup checksums, and
`final-counts.txt` records counts after the successful repeat run.
