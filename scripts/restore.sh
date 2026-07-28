#!/bin/bash
set -euo pipefail

BUCKET="${S3_BUCKET_NAME}"
RESTORE_CONTAINER="pg-restore-test"
DB_USER="appuser"
DB_NAME="appdb"
DB_PASS="apppass"

# Get the latest backup file from S3 (or accept one as an argument)
BACKUP_FILE="${1:-$(aws s3 ls "s3://$BUCKET/" | grep 'backup_' | sort | tail -n 1 | awk '{print $4}')}"
MANIFEST_FILE="manifest_${BACKUP_FILE#backup_}"
MANIFEST_FILE="${MANIFEST_FILE%.sql.gz}.json"

if [ -z "$BACKUP_FILE" ]; then
  echo "ERROR: no backup file found in bucket"
  exit 1
fi

echo "Restoring from: $BACKUP_FILE"
echo "Using manifest: $MANIFEST_FILE"

aws s3 cp "s3://$BUCKET/$BACKUP_FILE" "./$BACKUP_FILE"
aws s3 cp "s3://$BUCKET/$MANIFEST_FILE" "./$MANIFEST_FILE"

# Spin up a completely separate, throwaway Postgres instance
docker rm -f "$RESTORE_CONTAINER" 2>/dev/null || true
docker run -d --name "$RESTORE_CONTAINER" \
  -e POSTGRES_USER="$DB_USER" \
  -e POSTGRES_PASSWORD="$DB_PASS" \
  -e POSTGRES_DB="$DB_NAME" \
  postgres:16

echo "Waiting for restore container to be ready..."
for i in {1..15}; do
  docker exec "$RESTORE_CONTAINER" pg_isready -U "$DB_USER" && break
  sleep 2
done

# Decompress and restore
gunzip -c "$BACKUP_FILE" | docker exec -i "$RESTORE_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME"

echo "Restore complete into container: $RESTORE_CONTAINER"

# Export vars for verify.sh to use
echo "$RESTORE_CONTAINER" > .last_restore_container
echo "$MANIFEST_FILE" > .last_manifest_file
