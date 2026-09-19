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

require_env RAAHI_STORAGE_PROJECT_REF
require_env RAAHI_STORAGE_ENVIRONMENT
require_env RAAHI_STORAGE_SOURCE_REMOTE
require_env RAAHI_STORAGE_DEST_REMOTE
require_env RAAHI_STORAGE_DEST_PREFIX
require_env RAAHI_STORAGE_MANIFEST_DIR

case "$RAAHI_STORAGE_ENVIRONMENT" in
  DEV_TEST|PRODUCTION_LIKE|PRODUCTION) ;;
  *) fail "RAAHI_STORAGE_ENVIRONMENT must be DEV_TEST, PRODUCTION_LIKE, or PRODUCTION" ;;
esac

if [[ "$RAAHI_STORAGE_PROJECT_REF" == "hoshprxoyhjyyigxkang" ]]; then
  fail "The separate Where Is My Raahi project is forbidden for Raahi Learning backups"
fi

if [[ "$RAAHI_STORAGE_ENVIRONMENT" != "DEV_TEST" && "$RAAHI_STORAGE_PROJECT_REF" == "iiwwmqokaeflaenhlyip" ]]; then
  fail "Raahi Learning DEV cannot be labelled as production-like or production"
fi

[[ "$RAAHI_STORAGE_SOURCE_REMOTE" != "$RAAHI_STORAGE_DEST_REMOTE" ]] || fail "Source and destination rclone remotes must differ"

require_cmd rclone
require_cmd python3

buckets=(
  ads-public
  ads-review-private
  class-private
  community-public
  learner-private-media
  public-profile-media
)

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
manifest_dir="$RAAHI_STORAGE_MANIFEST_DIR/$RAAHI_STORAGE_PROJECT_REF/$timestamp"
mkdir -p "$manifest_dir"
summary="$manifest_dir/manifest.txt"

cat > "$summary" <<EOF
artifact=raahi-learning-storage-object-backup
project_ref=$RAAHI_STORAGE_PROJECT_REF
environment=$RAAHI_STORAGE_ENVIRONMENT
created_at_utc=$timestamp
source_remote=$RAAHI_STORAGE_SOURCE_REMOTE
destination_remote=$RAAHI_STORAGE_DEST_REMOTE
destination_prefix=$RAAHI_STORAGE_DEST_PREFIX
credential_material_in_manifest=false
restore_verified=false
EOF

printf 'Starting Raahi Learning Storage backup for %s (%s)\n' "$RAAHI_STORAGE_PROJECT_REF" "$RAAHI_STORAGE_ENVIRONMENT"
printf 'rclone credentials must be preconfigured outside this repository. No S3 key is read from this script.\n'

for bucket in "${buckets[@]}"; do
  source_path="$RAAHI_STORAGE_SOURCE_REMOTE:$bucket"
  destination_path="$RAAHI_STORAGE_DEST_REMOTE:$RAAHI_STORAGE_DEST_PREFIX/$timestamp/$bucket"
  source_json="$manifest_dir/$bucket.source-size.json"
  dest_json="$manifest_dir/$bucket.destination-size.json"

  printf 'Backing up bucket: %s\n' "$bucket"

  # Listing first makes a missing/misconfigured source bucket fail before copy.
  rclone lsf "$source_path" --max-depth 1 >/dev/null

  # Copy is intentionally non-destructive: never delete destination history.
  rclone copy "$source_path" "$destination_path" --checksum --fast-list

  rclone size "$source_path" --json > "$source_json"
  rclone size "$destination_path" --json > "$dest_json"

  python3 - "$bucket" "$source_json" "$dest_json" <<'PY'
import json
import sys

bucket, source_path, dest_path = sys.argv[1:4]
with open(source_path, encoding="utf-8") as f:
    source = json.load(f)
with open(dest_path, encoding="utf-8") as f:
    dest = json.load(f)

source_pair = (int(source.get("count", -1)), int(source.get("bytes", -1)))
dest_pair = (int(dest.get("count", -2)), int(dest.get("bytes", -2)))
if source_pair != dest_pair:
    raise SystemExit(
        f"Storage backup verification failed for {bucket}: "
        f"source(count,bytes)={source_pair} destination={dest_pair}"
    )
print(f"{bucket}: verified count={source_pair[0]} bytes={source_pair[1]}")
PY

  python3 - "$bucket" "$source_json" >> "$summary" <<'PY'
import json
import sys

bucket, source_path = sys.argv[1:3]
with open(source_path, encoding="utf-8") as f:
    data = json.load(f)
print(f"bucket.{bucket}.count={int(data.get('count', 0))}")
print(f"bucket.{bucket}.bytes={int(data.get('bytes', 0))}")
PY
done

printf 'storage_copy_verified=true\n' >> "$summary"
printf 'Storage backup and count/byte verification completed: %s\n' "$manifest_dir"
printf 'IMPORTANT: copy verification is not restore proof. Restore into an isolated target and verify checksums/authorization before claiming recovery readiness.\n'
