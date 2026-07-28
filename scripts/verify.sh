#!/bin/bash
set -euo pipefail

RESTORE_CONTAINER=$(cat .last_restore_container)
MANIFEST_FILE=$(cat .last_manifest_file)
DB_USER="appuser"
DB_NAME="appdb"

if [ ! -f "$MANIFEST_FILE" ]; then
  echo "ERROR: manifest file $MANIFEST_FILE not found"
  exit 1
fi

EXPECTED_ROWS=$(grep -o '"row_count": [0-9]*' "$MANIFEST_FILE" | awk '{print $2}')
ACTUAL_ROWS=$(docker exec -i "$RESTORE_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT count(*) FROM events;" | tr -d ' ')

echo "Expected row count: $EXPECTED_ROWS"
echo "Actual row count:   $ACTUAL_ROWS"

if [ "$EXPECTED_ROWS" != "$ACTUAL_ROWS" ]; then
  echo "VERIFICATION FAILED: row count mismatch"
  exit 1
fi

echo "VERIFICATION PASSED: restored data matches manifest"
