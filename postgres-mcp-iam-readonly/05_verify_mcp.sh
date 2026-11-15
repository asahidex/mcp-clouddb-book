#!/usr/bin/env bash
# 5. Check the MCP server without an LLM over stdio JSON-RPC (initialize, tools/list, run_query). Results go to verify_*.json.
#    Reproduces the "Verify" table in the article: SELECT, INSERT, EXPLAIN ANALYZE, and UPDATE with --allow_write_query.
set -euo pipefail; cd "$(dirname "$0")"; source ./env.sh
ARN=$(jq -r .arn state.json); EP=$(jq -r .ep state.json)
# The agent role has no secretsmanager:DescribeSecret, so read the secret ARN that 01 saved in state.json.
RO=$(jq -r .ro_secret state.json)
q(){ jq -n --arg l "$1" --arg s "$2" --arg c "$CLUSTER" --arg ep "$EP" --arg db "$DB_NAME" \
  '[{label:$l,tool:"run_query",arguments:{sql:$s,connection_method:"pgwire_iam",cluster_identifier:$c,db_endpoint:$ep,database:$db}}]'; }
q select "SELECT current_user, count(*) FROM products" > calls_select.json
q insert "INSERT INTO products VALUES (9,'kiwi',90)" > calls_insert.json
q explain "EXPLAIN ANALYZE SELECT * FROM products WHERE price > 100" > calls_explain.json
# UPDATE, then read the price back in the same session to show that it did not change
jq -s add <(q update "UPDATE products SET price = price + 1 WHERE id = 1") <(q price_after "SELECT price FROM products WHERE id = 1") > calls_update.json
CMD="uvx awslabs.postgres-mcp-server@$MCP_VERSION --connection_method PG_WIRE_IAM_PROTOCOL --secret_arn $RO --db_cluster_arn $ARN --db_endpoint $EP --database $DB_NAME --region $AWS_DEFAULT_REGION --db_type APG --privilege_check enforce"
python3 mcp_rpc.py "$CMD" calls_select.json verify_select.json verify_select.err
python3 mcp_rpc.py "$CMD" calls_insert.json verify_insert.json verify_insert.err
python3 mcp_rpc.py "$CMD" calls_explain.json verify_explain.json verify_explain.err
# Same settings plus the flag that allows writes. The database privileges should still reject the UPDATE.
python3 mcp_rpc.py "$CMD --allow_write_query" calls_update.json verify_update.json verify_update.err
jq -c '.calls[] | {label, result: .response.result.structuredContent}' verify_select.json verify_insert.json verify_explain.json verify_update.json
