#!/usr/bin/env bash
# 3. Check with psql that the calling IAM principal can connect as mcp_readonly (rds-db:connect).
set -euo pipefail; cd "$(dirname "$0")"; source ./env.sh
EP=$(jq -r .ep state.json)
aws sts get-caller-identity --query Arn --output text
TOKEN=$(aws rds generate-db-auth-token --hostname "$EP" --port 5432 --username "$RO_USER")
PGPASSWORD="$TOKEN" PGSSLMODE=require psql -h "$EP" -U "$RO_USER" -d "$DB_NAME" -At \
  -c "SELECT current_user" -c "SELECT count(*) FROM products"
