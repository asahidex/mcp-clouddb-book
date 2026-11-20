# Postgres MCP Server on Aurora as a read-only DB user with IAM database authentication

Scripts for the AWS Builder Center article "Connect the Postgres MCP Server to Aurora as a Read-Only Database User with IAM Database Authentication".

They create an Aurora PostgreSQL Serverless v2 cluster, a database user that can only run SELECT, an optional IAM role with only the three permissions the server needs, and the settings that let the [AWS Labs Postgres MCP Server](https://github.com/awslabs/mcp/tree/main/src/postgres-mcp-server) connect as that user with IAM database authentication (`PG_WIRE_IAM_PROTOCOL`). Then they check what is stopped and what runs, and delete everything.

Tested on 2026-11-20 in ap-northeast-1 with `awslabs.postgres-mcp-server` 1.2.4 and Aurora PostgreSQL 17.11.

## Prerequisites

- bash, `git`, AWS CLI v2, `jq`, `psql`, `curl`, Python 3, and `uv` (for `uvx`)
- An AWS account with a default VPC in the Region
- Permissions to create RDS clusters, security groups, and Secrets Manager secrets
- Optional: permissions to create and delete an IAM role (for `role_create.sh`)

## Cost

Aurora Serverless v2 is 0.15 USD per ACU-hour in ap-northeast-1 (as of 2026-11-11). With 0.5 to 2 ACU, one full run (create to delete, about 20 minutes: about 7 to create and 10 to 12 to delete) cost less than 0.1 USD. Run `99_cleanup.sh` when you finish.

## Steps

Edit `env.sh` first: replace `<profile>` with your AWS profile name, and change the Region if you need to. Keep the default resource names, because the SQL and policy examples use them. Then run the scripts in order, from the same terminal.

| Script | What it does |
|---|---|
| `01_create.sh` | Creates a security group that opens 5432 only to your current IP (/32), the cluster (Data API and IAM DB auth enabled, public access for this lab), a writer instance, and the secret that holds the user name. Saves ARNs and the endpoint to `state.json` |
| `02_dbsetup.sh` | Runs `02_dbsetup.sql` through the Data API with the master user secret: a sample table and the user `mcp_readonly` (`rds_iam`, SELECT only). The last line revokes `TEMPORARY` from `PUBLIC`, because PostgreSQL lets every user create temporary tables by default |
| `role_create.sh` (optional) | Creates the IAM role `cbsr2-mcp-readonly-agent` with only the three statements in `iam-policy.example.json`. Needs IAM permissions |
| `as_role.sh <command>` (optional) | Runs one command with that role's temporary credentials, for example `./as_role.sh ./03_check_iam.sh` |
| `role_delete.sh` (optional) | Deletes that role. `99_cleanup.sh` calls it if `role_policy.json` exists. Run it yourself only when someone else created the role for you |
| `03_check_iam.sh` | Connects with `psql` and an IAM auth token as `mcp_readonly`. Expect `mcp_readonly` and `8` |
| `04_mcp_config.sh` | Writes the MCP client configuration to `mcp.json` (see `mcp.example.json`) |
| `05_verify_mcp.sh` | Starts the MCP server and sends JSON-RPC directly (no LLM), as in the table in the article's Step 5: a SELECT that succeeds, an INSERT that the server's read-only mode rejects, an `EXPLAIN ANALYZE` that runs, and an UPDATE with `--allow_write_query` that the database rejects (the price stays 120) |
| `99_cleanup.sh` | Deletes the agent role (if you ran `role_create.sh`), the secret, instance, cluster, and security group, then prints `[]` for each if nothing is left |

`iam-policy.example.json` is the least-privilege policy for the agent's IAM principal. `role_create.sh` fills in the account ID and the cluster resource ID for you. To write it by hand, replace `<account-id>` and `<cluster-resource-id>` (from `aws rds describe-db-clusters --query 'DBClusters[0].DbClusterResourceId'`).

### Run 03 to 05 as the agent role (optional)

Without this, 03 to 05 run with your own profile, which usually has far more permissions than the agent should have.

```bash
./role_create.sh
./as_role.sh ./03_check_iam.sh
./as_role.sh ./04_mcp_config.sh
./as_role.sh ./05_verify_mcp.sh
```

The results are the same as with your own profile. The only difference is one WARNING in `verify_select.err` about `rds:DescribeDBInstances`, which the role does not have and the server does not need. If you sign in with IAM Identity Center or another role, the trust policy falls back to your account, and you also need `sts:AssumeRole` in your own permissions (or set `TRUST_PRINCIPAL_ARN`).

### If someone else manages IAM

If you cannot create IAM roles yourself, ask your IAM administrator to run two scripts. You run everything else.

1. Run `01_create.sh` and `02_dbsetup.sh` yourself. `role_create.sh` looks up the cluster, so the cluster must exist first.
2. The administrator clones this repository and moves into this folder. Only `env.sh`, `role_create.sh`, and `role_delete.sh` are used. They need `jq`, the same Region and resource names in `env.sh` as yours, and their own profile name in place of `<profile>` (in AWS CloudShell, leave `env.sh` as it is: no profile is needed there. CloudShell sets `AWS_DEFAULT_REGION` to the console's Region, so open it in the cluster's Region). They also need these permissions: `rds:DescribeDBClusters`, `iam:CreateRole`, `iam:PutRolePolicy`, `iam:GetRolePolicy`, and for the cleanup `iam:DeleteRolePolicy` and `iam:DeleteRole`.
3. They run this, with your IAM user or role ARN as the principal that may assume the role:

   ```bash
   TRUST_PRINCIPAL_ARN=<your-principal-arn> ./role_create.sh
   ```

   It prints the role name and the three statement IDs (`ConnectAsReadOnlyDbUser`, `ReadUserNameSecret`, `ServerStartupClusterCheck`). Without `TRUST_PRINCIPAL_ARN`, the role would trust the administrator, not you.
4. You run 03 to 05 with `./as_role.sh`, as above. If your principal is a role session, you also need `sts:AssumeRole` on the new role in your own permissions.
5. When you finish, run `99_cleanup.sh`. It does not delete the role, because `role_policy.json` is not in your folder. Ask the administrator to run `./role_delete.sh`, then check that the role is gone: `aws iam get-role --role-name cbsr2-mcp-readonly-agent` should fail with `NoSuchEntity`.

For what to check before you use this setup on a real database (heavy queries, functions that write, other databases in the cluster, audit, token lifetime), see [PRODUCTION.md](PRODUCTION.md).

## Notes

- The user-name secret needs a `password` key even though IAM auth does not use it. Without it, 1.2.4 exits with `Secret does not contain password`.
- The server calls `rds:DescribeDBClusters` at startup, so the agent's policy needs it. `rds:DescribeDBInstances` is optional (only a warning without it).
- Public access is for this lab only. In production, run the MCP server where it can reach port 5432 inside the VPC.
- Generated files (`state.json`, `mcp.json`, `calls_*.json`, `verify_*`, `role_*.json`) contain your account's ARNs and endpoints. They are in `.gitignore`.
