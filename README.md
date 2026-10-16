# biodiversity-surveys

Shared documentation, architectural decisions, and development tools for
protocol-driven biodiversity surveys built on iNaturalist.

This repository tracks `docs/`, `bin/`, and workspace instructions. The following
application checkouts have independent Git histories and are ignored here:

- `web`: Rails models, PostgreSQL/PostGIS schema, authorization, web UI, and
  legacy/write endpoints
- `api`: public Node API and OpenAPI/Swagger infrastructure
- `mobile`: React Native iOS client and its local Realm persistence

## Set up application checkouts

In a fresh workspace, clone the applications separately:

```bash
git clone --branch feature/survey-schema-v0.2 https://github.com/spacemansteve/inaturalist.git web
git -C web remote add upstream https://github.com/inaturalist/inaturalist.git
git clone https://github.com/inaturalist/iNaturalistAPI.git api
git clone https://github.com/inaturalist/iNaturalistReactNative.git mobile
```

Follow each application's setup instructions to install dependencies and supply
local configuration. This workspace does not include runtimes, credentials,
downloaded datasets, or initialized databases. There are no Git submodules;
commit and push application changes from their respective directories.

The local workspace directory may have any name, including `Swifty`. `env.sh`
derives its location when sourced from Bash and retains `SWIFTY_ROOT` as a
compatibility alias. Existing `RBENV_ROOT` and `DOCKER_CONFIG` settings take
precedence over workspace defaults.

## Current local toolchain

The existing Apple Silicon macOS environment uses the following tools. These
are prerequisites to reproduce that environment, not bundled installations:


- Node.js 24.15.0 in `.toolchains/node-24.15.0`
- Ruby 3.3.7 (Rails) and 3.4.5 (mobile) under `.toolchains/rbenv`
- Xcode 26.6 and CocoaPods 1.15.2 through the mobile bundle
- Docker CLI/Compose with Colima, Rosetta container emulation, and QEMU
- PostgreSQL client, Watchman, GDAL, GEOS, PROJ, ImageMagick, ExifTool, and FFmpeg

Run `source ./env.sh` in each new shell. The repository `.ruby-version` files
then select the correct workspace Ruby automatically.

## Start the stack

```bash
./bin/start-services
```

In separate terminals:

```bash
./bin/start-web       # http://127.0.0.1:3000
./bin/start-api       # http://127.0.0.1:4000
./bin/start-mobile    # Metro bundler
```

From another sourced shell, launch the iOS simulator build:

```bash
cd mobile
npm run ios
```

Stop the data services without deleting their volumes:

```bash
./bin/stop-services
```

## Local configuration

The following describes the existing development machine, not a fresh clone.

The `bin/start-web` and `bin/start-api` launchers now select the populated
`inaturalist_survey_candidate_20261014` database and
`survey_candidate_20261014` Elasticsearch indexes through
`bin/development/environment.sh`. The original database is retained for rollback.
See [application cutover](docs/engineering/application-cutover.md) for verification
URLs, worker configuration, and rollback commands.

The mobile `.env` files and Firebase plist files are copied from repository
examples. Replace placeholder OAuth, maps, Firebase, and signing credentials
before testing those integrations. The example AI camera model, geomodel, and
taxonomy files are installed for both platforms.

The Rails development and test databases are initialized with schema, iconic
taxa, sources, controlled terms, translations, and Elasticsearch indexes.

The scripts under `bin/development/` document the October 14 candidate-data
import and retain safeguards for that specific database and snapshot. Read the
[initialization plan](docs/engineering/development-database-initialization.md)
and [load record](docs/engineering/development-database-load-record.md) before
using them; they are not automatic fresh-install setup scripts.

Only `resources/inaturalist/README.md` is tracked under `resources/`; downloads,
import output, and backups stay local. `.gitignore` also excludes local toolchains,
Docker configuration, environment secrets, logs, and the existing `foo.txt`
scratch file.

## Survey engineering guidance

Read the [Survey engineering guidelines](docs/engineering/inaturalist-survey-guidelines.md)
before planning or implementing changes. Investigate existing Trips and related
iNaturalist concepts before choosing a Survey representation. Prefer the
smallest coherent extension that preserves existing behavior and compatibility
with upstream.

Start by studying the existing application, then implement one minimal web
workflow. Extend the separate API only when a concrete requirement demonstrates
the need; expand mobile and offline support after the core model is proven.

The [documentation index](docs/README.md) organizes shared engineering guidance
and architectural decision records. [AGENTS.md](AGENTS.md) makes this guidance
discoverable to coding agents working in the workspace.
