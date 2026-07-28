#!/bin/bash
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_${TIMESTAMP}.sql.gz"
MANIFEST_FILE="manifest_${TIMESTAMP}.json"

DB_CONTAINER="pg-db"
DB_USER="appuser"
DB_NAME="appdb"
BUCKET="${S3_BUCKET_NAME}"

echo "Starting backup: $BACKUP_FILE"

# Dump and compress
docker exec -i "$DB_CONTAINER" pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"

# Fail loudly if the dump is empty
if [ ! -s "$BACKUP_FILE" ]; then
  echo "ERROR: backup file is empty!"
  exit 1
fi

# Build a manifest for later verification
ROW_COUNT=$(docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT count(*) FROM events;" | tr -d ' ')
CHECKSUM=$(sha256sum "$BACKUP_FILE" | awk '{print $1}')

cat > "$MANIFEST_FILE" << MANIFEST
{
  "backup_file": "$BACKUP_FILE",
  "timestamp": "$TIMESTAMP",
  "row_count": $ROW_COUNT,
  "checksum": "$CHECKSUM"
}
MANIFEST

echo "Uploading $BACKUP_FILE and $MANIFEST_FILE to s3://$BUCKET/"
aws s3 cp "$BACKUP_FILE" "s3://$BUCKET/$BACKUP_FILE"
aws s3 cp "$MANIFEST_FILE" "s3://$BUCKET/$MANIFEST_FILE"

# Clean up local files
rm "$BACKUP_FILE" "$MANIFEST_FILE"

echo "Backup complete: $BACKUP_FILE"
