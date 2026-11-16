#!/usr/bin/env bash
# Optional (needs IAM permissions): create the agent's IAM role with only the three statements the MCP server needs.
# Run it after 02. Then run 03 to 05 as that role:  ./as_role.sh ./03_check_iam.sh
set -euo pipefail; cd "$(dirname "$0")"; source ./env.sh
ACCT=$(aws sts get-caller-identity --query Account --output text)
ME=$(aws sts get-caller-identity --query Arn --output text)
# Who may assume the role. An IAM user: that user only. A role session (SSO, AssumeRole): this account,
# where the caller also needs sts:AssumeRole in its own policy. Set TRUST_PRINCIPAL_ARN to choose another principal.
case "$ME" in *:user/*) DEFAULT_TRUST=$ME ;; *) DEFAULT_TRUST="arn:aws:iam::$ACCT:root" ;; esac
TRUST=${TRUST_PRINCIPAL_ARN:-$DEFAULT_TRUST}
# rds-db:connect takes the cluster resource ID (cluster-XXXX), not the cluster name.
RID=$(aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER" --query 'DBClusters[0].DbClusterResourceId' --output text)
R=$AWS_DEFAULT_REGION
jq -n --arg t "$TRUST" '{Version:"2012-10-17",Statement:[{Effect:"Allow",Principal:{AWS:$t},Action:"sts:AssumeRole"}]}' > role_trust.json
# Same three statements as iam-policy.example.json. "-??????" matches the six random characters Secrets Manager adds to the ARN.
jq -n --arg db "arn:aws:rds-db:$R:$ACCT:dbuser:$RID/$RO_USER" \
      --arg sec "arn:aws:secretsmanager:$R:$ACCT:secret:$RO_SECRET-??????" \
      --arg cl "arn:aws:rds:$R:$ACCT:cluster:$CLUSTER" '{Version:"2012-10-17",Statement:[
  {Sid:"ConnectAsReadOnlyDbUser",Effect:"Allow",Action:"rds-db:connect",Resource:$db},
  {Sid:"ReadUserNameSecret",Effect:"Allow",Action:"secretsmanager:GetSecretValue",Resource:$sec},
  {Sid:"ServerStartupClusterCheck",Effect:"Allow",Action:"rds:DescribeDBClusters",Resource:$cl}]}' > role_policy.json
aws iam create-role --role-name "$AGENT_ROLE" --assume-role-policy-document file://role_trust.json --query Role.RoleName --output text
aws iam put-role-policy --role-name "$AGENT_ROLE" --policy-name "$AGENT_ROLE-min" --policy-document file://role_policy.json
aws iam get-role-policy --role-name "$AGENT_ROLE" --policy-name "$AGENT_ROLE-min" --query 'PolicyDocument.Statement[].Sid' --output text
