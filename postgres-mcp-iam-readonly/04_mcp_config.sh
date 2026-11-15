#!/usr/bin/env bash
# 4. Generate the MCP client configuration (mcpServers JSON) from state.json and write it to mcp.json.
set -euo pipefail; cd "$(dirname "$0")"; source ./env.sh
ARN=$(jq -r .arn state.json); EP=$(jq -r .ep state.json)
# The agent role has no secretsmanager:DescribeSecret, so read the secret ARN that 01 saved in state.json.
RO=$(jq -r .ro_secret state.json)
jq -n --arg v "$MCP_VERSION" --arg arn "$ARN" --arg ep "$EP" --arg sec "$RO" --arg db "$DB_NAME" \
  --arg p "$AWS_PROFILE" --arg r "$AWS_DEFAULT_REGION" '{mcpServers:{"postgres-readonly":{
  command:"uvx",
  args:["awslabs.postgres-mcp-server@\($v)","--connection_method","PG_WIRE_IAM_PROTOCOL",
        "--secret_arn",$sec,"--db_cluster_arn",$arn,"--db_endpoint",$ep,
        "--database",$db,"--region",$r,"--db_type","APG","--privilege_check","enforce"],
  env:{AWS_PROFILE:$p,AWS_REGION:$r}}}}' | tee mcp.json
