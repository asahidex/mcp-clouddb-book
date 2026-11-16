#!/usr/bin/env bash
# Run one command with the agent role's temporary credentials (no profile):  ./as_role.sh ./05_verify_mcp.sh
# A role you have just created can take a few seconds before it can be assumed. Retry if AssumeRole fails.
set -euo pipefail; cd "$(dirname "$0")"; source ./env.sh
ACCT=$(aws sts get-caller-identity --query Account --output text)
CRED=$(aws sts assume-role --role-arn "arn:aws:iam::$ACCT:role/$AGENT_ROLE" --role-session-name cbsr2-agent --query Credentials --output json)
unset AWS_PROFILE
eval "$(jq -r '@sh "export AWS_ACCESS_KEY_ID=\(.AccessKeyId) AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey) AWS_SESSION_TOKEN=\(.SessionToken)"' <<<"$CRED")"
unset CRED
exec "$@"
