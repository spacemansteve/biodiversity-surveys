# Shared local application data selection. Source after the workspace env.sh.
# Explicit environment overrides allow rollback without editing these defaults.
export INAT_DB_NAME="${INAT_DB_NAME:-inaturalist_survey_candidate_20261014}"
export INAT_ES_INDEX_PREFIX="${INAT_ES_INDEX_PREFIX:-survey_candidate_20261014}"
export DATABASE_URL="${DATABASE_URL:-postgis://inaturalist:inaturalist@localhost/$INAT_DB_NAME}"
