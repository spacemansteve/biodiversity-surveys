# Local application cutover

Completed October 14, 2026. Both workspace launchers now source
`bin/development/environment.sh` after `env.sh` and use:

- PostgreSQL: `inaturalist_survey_candidate_20261014`
- Elasticsearch prefix: `survey_candidate_20261014`
- Rails: `http://localhost:3000`
- API: `http://localhost:4000`

Start normally from the workspace using `./bin/start-web` and `./bin/start-api`
in separate terminals. Infrastructure is started with `./bin/start-services`.
No repository application code, test database settings, or production settings
were changed. The original database and indexes are retained.

## Verification

- Candidate Elasticsearch taxa count: 1,668,467; no failed shards.
- `http://localhost:4000/v1/taxa?per_page=1`: HTTP 200,
  `total_results` 1,433,587 (active taxa by default).
- `http://localhost:4000/v1/taxa/48460`: HTTP 200, Life at ID 48460.
- `http://localhost:4000/v1/taxa?q=Quercus%20alba&per_page=2`:
  HTTP 200, Quercus alba at ID 54779.
- Rails `/taxa`, `/search`, and `/taxa/54779`: HTTP 200.
- Rails `/taxa/48460` intentionally redirects to `/taxa` for the Life root.
- PostgreSQL connections for Rails and the API both target the candidate database.

Webpack bundles were already present at cutover. The HTTP checks confirm server
rendering and API search; they are not a complete browser interaction test.
The full rebuild log reached all models, including ExemplarIdentification.

Cutover server logs are in `resources/inaturalist/2026-10-14/cutover/`.
The original load validation report is historical and predates this cutover.

## Other commands and workers

Direct Rails commands and any future background workers must select the same
database and search prefix. From the workspace:

```bash
source ./env.sh
source ./bin/development/environment.sh
cd web
# Run the required Rails command or worker here.
```

No background worker was started during cutover. Avoid running `db:reset` or
`bin/setup` against the populated database.

## Rollback

Stop both application servers, then launch each in its own terminal:

```bash
DATABASE_URL=postgis://inaturalist:inaturalist@localhost/inaturalist_development \
INAT_DB_NAME=inaturalist_development INAT_ES_INDEX_PREFIX=development \
./bin/start-web
```

```bash
DATABASE_URL=postgis://inaturalist:inaturalist@localhost/inaturalist_development \
INAT_DB_NAME=inaturalist_development INAT_ES_INDEX_PREFIX=development \
./bin/start-api
```

The override is for those processes only; the launchers' defaults remain the
populated candidate. Keep both servers and any workers on the same selection.
