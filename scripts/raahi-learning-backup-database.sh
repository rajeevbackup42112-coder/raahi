#!/usr/bin/env bash
set -euo pipefail
umask 077

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "Missing required environment variable: $name"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_env RAAHI_BACKUP_PROJECT_REF
require_env RAAHI_BACKUP_ENVIRONMENT
require_env RAAHI_LEARNING_DB_URL
require_env RAAHI_BACKUP_DIR

case "$RAAHI_BACKUP_ENVIRONMENT" in
  DEV_TEST|PRODUCTION_LIKE|PRODUCTION) ;;
  *) fail "RAAHI_BACKUP_ENVIRONMENT must be DEV_TEST, PRODUCTION_LIKE, or PRODUCTION" ;;
esac

if [[ "$RAAHI_BACKUP_PROJECT_REF" == "hoshprxoyhjyyigxkang" ]]; then
  fail "The separate Where Is My Raahi project is forbidden for Raahi Learning backups"
fi

if [[ "$RAAHI_BACKUP_ENVIRONMENT" != "DEV_TEST" && "$RAAHI_BACKUP_PROJECT_REF" == "iiwwmqokaeflaenhlyip" ]]; then
  fail "Raahi Learning DEV cannot be labelled as production-like or production"
fi

if [[ "$RAAHI_LEARNING_DB_URL" != *"$RAAHI_BACKUP_PROJECT_REF"* ]]; then
  fail "Database URL does not appear to match RAAHI_BACKUP_PROJECT_REF"
fi

require_cmd supabase

if command -v sha256sum >/dev/null 2>&1; then
  HASH_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  HASH_CMD="shasum -a 256"
else
  fail "sha256sum or shasum is required"
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
target_dir="$RAAHI_BACKUP_DIR/$RAAHI_BACKUP_PROJECT_REF/$timestamp"
mkdir -p "$target_dir"

roles="$target_dir/roles.sql"
schema="$target_dir/schema.sql"
data="$target_dir/data.sql"
manifest="$target_dir/manifest.txt"
checksums="$target_dir/SHA256SUMS"

printf 'Creating logical database backup for project %s (%s)\n' "$RAAHI_BACKUP_PROJECT_REF" "$RAAHI_BACKUP_ENVIRONMENT"
printf 'Credentials are supplied through RAAHI_LEARNING_DB_URL and are not written to the manifest.\n'

supabase db dump --db-url "$RAAHI_LEARNING_DB_URL" -f "$roles" --role-only
supabase db dump --db-url "$RAAHI_LEARNING_DB_URL" -f "$schema"
supabase db dump --db-url "$RAAHI_LEARNING_DB_URL" -f "$data" --use-copy --data-only

[[ -s "$roles" ]] || fail "roles.sql is empty"
[[ -s "$schema" ]] || fail "schema.sql is empty"
[[ -s "$data" ]] || fail "data.sql is empty"

(
  cd "$target_dir"
  # shellcheck disable=SC2086
  $HASH_CMD roles.sql schema.sql data.sql > SHA256SUMS
)

cat > "$manifest" <<EOF
artifact=raahi-learning-logical-database-backup
project_ref=$RAAHI_BACKUP_PROJECT_REF
environment=$RAAHI_BACKUP_ENVIRONMENT
created_at_utc=$timestamp
roles_file=roles.sql
schema_file=schema.sql
data_file=data.sql
checksums_file=SHA256SUMS
credential_material_in_manifest=false
restore_verified=false
EOF

printf 'Backup created: %s\n' "$target_dir"
printf 'IMPORTANT: backup creation is not restore proof. Restore into an isolated target before claiming recovery readiness.\n'
