# Development database initialization

Status: downloads and candidate database loading completed October 14, 2026.
See the [load record](development-database-load-record.md) for execution details
and validation. The original database and application configuration remain unchanged.

## Sources and downloaded data

The official [inaturalist-open-data repository](https://github.com/inaturalist/inaturalist-open-data)
documents monthly exports hosted in the public AWS S3 bucket. These are selected
metadata exports, not PostgreSQL backups of the complete Rails database.
The [metadata documentation](https://github.com/inaturalist/inaturalist-open-data/blob/main/Metadata/README.md)
describes the available columns.

Downloads are in `resources/inaturalist/2026-10-14/` relative to the workspace:

| File | Purpose |
| --- | --- |
| `taxa.csv.gz` | Latest standalone taxonomy snapshot; last modified September 27, 2026; 39,999,332 compressed bytes |
| `iconic-taxa.json` | 13 current iconic taxa with production IDs, fetched in one small API request |
| `controlled-terms.json` | 7 current annotation attributes with nested values and taxonomic restrictions, fetched in one small API request |
| `ne_50m_admin_0_countries.zip` | Natural Earth country boundaries, from the URL used by the upstream country importer |
| `metadata-README.md`, `download-README.md`, `README.upstream.md` | Upstream dataset documentation |
| `snapshot-list.xml` | S3 archive listing at download time |
| `manifest.json` | File sizes, SHA-256 checksums, primary data URLs, and retrieval date |
| `taxa-validation.json` | Taxonomy validation results |

HTTP response headers are retained alongside the primary downloads. SHA-256
values record the downloaded bytes for reproducibility; they are local checksums,
not independently published signatures. The small API reference lists are current
as of retrieval and are not guaranteed to be from the same date as the taxonomy.

The compressed taxonomy was read through to EOF, validating gzip integrity.
It contains 1,668,467 distinct IDs: 1,433,587 active and 234,880 inactive taxa.
All referenced ancestors exist. The actual ancestry separator is `/`.
Life (48460) is the only active root; inactive taxa can have empty ancestry.
The country ZIP passed its integrity check; both API responses parsed successfully.

The latest dated combined archive is `metadata/inaturalist-open-data-20260927.tar.gz`
(35,966,549,880 bytes). We did not download the worldwide observation, observer,
and photo metadata bundle: it is unnecessary for the initial Survey workflow.
The taxa export does not supply common names, taxon-change history, conservation
statuses, taxon frameworks, places, or full application records. Inactive taxa
alone do not establish mappings to their current replacements.

## Existing local database

The following describes the original database, retained alongside the new
`inaturalist_survey_candidate_20261014` candidate.

Read-only inspection of `inaturalist_development` found 70 taxa, 11 controlled
terms, zero users, zero observations, and zero places. PostgreSQL, Elasticsearch,
Redis, and Memcached containers are running.

The seed taxonomy uses locally allocated IDs: Life is 1 and Animalia is 2.
Production uses Life 48460 and Animalia 1. Therefore, importing with an upsert on
ID would overwrite unrelated taxa and invalidate existing relationships.

Relevant upstream code:

- `web/bin/setup` runs `db:reset`: do not rerun it against the current database.
- `web/tools/development_tools/taxon_importer/taxon_importer.rb` looks up taxa by
  name/rank and allocates local IDs; it is unsuitable for preserving production IDs.
- `web/tools/load_production_controlled_terms.rb` resolves taxonomic restrictions
  by name and may invoke that importer; verify exact ID relationships when adapting
  it for the downloaded data.
- `web/tools/load_sources.rb` supplies application citation records.
- `web/tools/import_natural_earth_countries.rb` supplies a country import pattern.
- `web/app/models/taxon.rb` maintains scientific names, iconic relationships,
  and search indexing through callbacks that a raw SQL import would bypass.

## Proposed initialization sequence

1. Back up the current local database with `pg_dump` and record the web/API commit
   hashes. Create a separate candidate database with PostGIS and UUID extensions,
   using the checked-out Rails structure and migrations. Keep the existing database
   and test database intact. Use separate Elasticsearch index names for the candidate.
2. Load the download into a staging table with its six source columns. Parse as
   tab-separated text with quoting disabled. Validate uniqueness, types, field
   lengths, ancestor existence, ancestry cycles, and rank relationships before
   touching application tables. Account explicitly for inactive/unplaced taxa.
3. Implement a development-only importer for the empty candidate database. Preserve
   `taxon_id` as `taxa.id`, map `active` to `is_active`, and retain ancestry, rank,
   rank level, and scientific name. Include active and inactive taxa. Refuse a
   nonempty target taxonomy or incompatible schema. Do not disable existing model
   validations to make an import pass; first test the supported model path with a
   small ancestor-complete subset. If bulk loading is needed, document and test all
   callback-derived data requirements before selecting that path.
4. Load citation sources and reconstruct required scientific `TaxonName` records
   and iconic relationships using the existing model conventions. Reconcile the
   downloaded iconic list against the snapshot. Advance ID sequences beyond imported
   maxima so local inserts cannot collide with imported IDs. This is development
   initialization, not a general two-way taxonomy synchronization system.
5. Import the saved controlled terms, values, labels, UUIDs, and restrictions using
   existing models, resolving restrictions by exact taxon ID. Stop and report any
   references missing from the older snapshot. Import country boundaries using the
   upstream pattern and retain attribution. Natural Earth places get local IDs;
   do not represent them as production iNaturalist place IDs.
6. Create local test users and a small synthetic observation/Trip dataset through
   normal application models. Add a local survey site as needed. Add common names,
   conservation data, and any specific real test observations only as concrete
   workflows require them; use approved bulk sources or narrowly bounded requests.
   Do not infer geoprivacy from taxonomy alone or treat this dataset as production
   privacy configuration.
7. Build candidate Elasticsearch indexes with upstream tasks. Check exact known
   IDs, ancestry traversal, scientific-name lookup, active/inactive behavior,
   controlled-term restrictions, and sequence safety. Smoke-test taxon search,
   observation creation, and Trip associations in Rails and the local API.
8. After validation, switch the local application/API database and search-index
   configuration together. Retain the original database and indexes for rollback.
   Record loaded source checksums and importer version. Keep automated tests on
   small fixtures; they should not depend on this full snapshot.

This approach preserves production taxon identifiers without rewriting existing
local identifiers. A future refresh requires a separate reconciliation design:
do not blindly delete missing taxa or overwrite historical Survey references.
No Survey schema, public API semantics, or production deployment changes are
needed for the proposed initialization.
