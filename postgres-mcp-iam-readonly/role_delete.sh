#!/usr/bin/env bash
# Delete the agent role that role_create.sh made (needs IAM permissions). 99_cleanup.sh calls this if role_policy.json exists.
set -uo pipefail; cd "$(dirname "$0")"; source ./env.sh
aws iam delete-role-policy --role-name "$AGENT_ROLE" --policy-name "$AGENT_ROLE-min"
aws iam delete-role --role-name "$AGENT_ROLE" && rm -f role_trust.json role_policy.json && echo "deleted role $AGENT_ROLE"
