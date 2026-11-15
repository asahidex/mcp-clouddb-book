#!/usr/bin/env bash
# 2. Create the table and the read-only user through the Data API with the master user secret. One statement per line in the SQL file.
set -euo pipefail; cd "$(dirname "$0")"; source ./env.sh
ARN=$(jq -r .arn state.json); MSEC=$(jq -r .master_secret state.json)
while IFS= read -r q; do
  [ -z "$q" ] && continue
  echo ">> $q"
  aws rds-data execute-statement --resource-arn "$ARN" --secret-arn "$MSEC" --database "$DB_NAME" --sql "$q" \
    --query numberOfRecordsUpdated --output text
done < 02_dbsetup.sql
