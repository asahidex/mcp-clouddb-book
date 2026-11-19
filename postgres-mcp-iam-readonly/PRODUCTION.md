# Before you take this to production

What I checked beyond the lab steps, on the cluster these scripts create (ap-northeast-1, `awslabs.postgres-mcp-server` 1.2.4, Aurora PostgreSQL 17.11, 2026-11-17 and 2026-11-19). Each item says what I tried, what happened, and what to do. Error texts are copied from the logs. The last section lists what I did not test.

Two terms used below:

- **Default mode**: the MCP server as configured in Step 4 (no `--allow_write_query`). It checks each statement and runs it in a read-only transaction.
- **Write-enabled**: the same server started with `--allow_write_query`. Treat this as "the first layer is gone", because someone can add the flag later.

## Privileges of the database user

### Functions that write

- Tried: a `SECURITY DEFINER` function owned by `postgres` that does an INSERT, called as `mcp_readonly`. The privilege to execute functions is granted to `PUBLIC` by default.
- Result: in default mode the call failed with `ReadOnlySqlTransaction: cannot execute INSERT in a read-only transaction`. Write-enabled, the INSERT succeeded and the row count went from 8 to 9, although `mcp_readonly` has no INSERT privilege on the table. After `REVOKE EXECUTE ON FUNCTION ... FROM PUBLIC`, the database rejected the call with `permission denied for function`, write-enabled or not.
- Do: revoke EXECUTE from `PUBLIC` on every `SECURITY DEFINER` function that writes, and grant it only to the users that need it.

### `default_transaction_read_only` is not a boundary

- Tried: `ALTER ROLE mcp_readonly SET default_transaction_read_only = on`, then the same function call.
- Result: the call failed with `cannot execute INSERT in a read-only transaction`, even write-enabled. But the user can turn the setting off for its own session. After `SET default_transaction_read_only = off` (or `BEGIN READ WRITE`, or `SET TRANSACTION READ WRITE`), the function inserted a row again, both in `psql` and through a write-enabled MCP server. Default mode rejects the `SET` itself.
- Do: don't rely on it. Use privileges (`REVOKE EXECUTE`, no write grants). The scripts do not set it, also because it changes the Step 5 error from `permission denied for table products` to `cannot execute UPDATE in a read-only transaction`, which hides whether the privileges work.

### `REVOKE TEMPORARY` covers one database

- Tried: `psql` as `mcp_readonly` to the database `postgres` instead of `appdb`, then `CREATE TEMP TABLE`. Also the MCP tool `connect_to_database` with `database: postgres` under the Step 4 configuration, then `CREATE TEMP TABLE` write-enabled.
- Result: both connected, and both created the temporary table. `02_dbsetup.sql` revokes `TEMPORARY` only on `appdb`, and `PUBLIC` can connect to `postgres` by default. `has_database_privilege` showed CONNECT true and TEMPORARY true for `postgres`.
- Do: for every other database in the cluster, run `REVOKE CONNECT ON DATABASE <name> FROM PUBLIC` (and grant CONNECT back to the users that need it), or revoke `TEMPORARY` there too.
- Also: the `REVOKE` on `appdb` affects every ordinary user of that database. `GRANT TEMPORARY ON DATABASE appdb TO <user>` gave it back to that user only; `mcp_readonly` was still denied.

### `ALTER DEFAULT PRIVILEGES` covers one creator

- Tried: another role created a table after the setup.
- Result: SELECT as `mcp_readonly` failed with `permission denied for table`. `ALTER DEFAULT PRIVILEGES FOR ROLE postgres` applies only to tables that `postgres` creates. After the same statement for the other role, a table created afterwards was readable; the table created before it stayed unreadable.
- Do: run the statement for every role that creates tables, and `GRANT SELECT` on tables that already exist. `GRANT SELECT ON ALL TABLES` exposes every column of every table in `public`; grant table by table if some must stay hidden.

### Other things the user can and cannot do

- `CREATE TABLE public.hack(i int)` failed with `permission denied for schema public` (`psql` and write-enabled MCP). This cluster was created on 17.11; see "Not tested" for upgraded databases.
- `SELECT ... FOR UPDATE` and `LOCK TABLE` on `products` failed with `permission denied for table products` when write-enabled. Default mode rejected them earlier.
- `pg_stat_activity` shows the user names and database names of other sessions. Their query text is `<insufficient privilege>`.
- A user with `rds_iam` cannot log in with a password. After the master user set a password on `mcp_readonly`, `psql` with that password failed with `PAM authentication failed for user "mcp_readonly"`, and so did the Data API with a secret that held it. So you cannot use this user through the Data API.

## Heavy queries and session settings

- Tried: `ALTER ROLE mcp_readonly SET statement_timeout = '2s'`, then `SELECT count(*) FROM generate_series(1, 300000000)` through the MCP server.
- Result: it came back after about 2 seconds with `QueryCanceled: canceling statement due to statement timeout`.
- Limits of this:
  - The user can change its own setting. Default mode rejected `SET statement_timeout = 0` (`Statement type not allowed in read-only mode: VariableSetStmt`) and `set_config(...)`. Write-enabled, both succeeded, `SHOW statement_timeout` returned `0`, and the heavy SELECT was still running after 120 seconds. `SET work_mem = '1GB'` succeeded the same way.
  - With the 2-second timeout, the MCP server once failed to start: `Refusing to start: Could not verify connection role privileges: QueryCanceled: canceling statement due to statement timeout. Rejecting connection (fail-closed).` The next start succeeded. The timeout also applies to the server's own startup check, so don't set it too short.
- Do: set `statement_timeout` as a default, not as a guarantee, and keep the server in default mode. `CONNECTION LIMIT` also works: with `CONNECTION LIMIT 0`, `psql` failed with `too many connections for role "mcp_readonly"` and the MCP server did not start.

## What default mode rejected, and what write-enabled let through

All as `mcp_readonly`. "DB" means the statement reached the database.

| Statement | Default mode | Write-enabled |
|---|---|---|
| `SET ...`, `set_config()` | rejected by the server | ran |
| `NOTIFY ch, 'x'` | rejected (`NotifyStmt`) | ran |
| `SELECT lo_creat(-1)` | rejected (`Function mutates state and is not allowed in read-only mode: lo_creat`) | ran; a large object was created |
| `SELECT pg_advisory_lock(42)`, `SELECT pg_notify('ch','x')` | rejected (`Dangerous function call not allowed`) | rejected, same message |
| `CREATE TEMP TABLE` | rejected (`CreateStmt`) | DB: `permission denied to create temporary tables in database "appdb"` |
| `LOCK TABLE`, `SELECT ... FOR UPDATE` | rejected | DB: `permission denied for table products` |
| `UPDATE` on the table | rejected | DB: `permission denied for table products` |

So the things that write-enabled lets through for a SELECT-only user are session settings, `NOTIFY`, large objects, and functions that `PUBLIC` may execute. If these matter, `REVOKE` them in the database (for example, `REVOKE EXECUTE ON FUNCTION lo_creat(oid) FROM PUBLIC`; I did not test this revoke).

## IAM and the connection

- **Enabling IAM DB authentication on an existing cluster**: `aws rds modify-db-cluster --enable-iam-database-authentication` without `--apply-immediately` stayed pending (`PendingModifiedValues` held `true`), and a token connection failed with `password authentication failed for user "mcp_readonly"`. With `--apply-immediately` it was enabled in 76 seconds.
- **Memory**: the [documented limitations](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/UsingWithRDS.IAMDBAuth.html) say IAM DB authentication needs 300 to 1,000 MiB of extra memory. Short connections worked with 0.5 to 2 ACU; include this when you choose the minimum ACU.
- **Source of connections**: IAM DB authentication does not support condition keys such as `aws:SourceIp` or `aws:SourceVpc` (same page). Limit the source with the security group, and run the MCP server where it reaches port 5432 inside the VPC. Public access is for the lab only.
- **Certificate verification**: `psql` with `PGSSLMODE=verify-full` and the [RDS certificate bundle](https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem) in `PGSSLROOTCERT` connected. The 1.2.4 MCP server already connects with `verify-full` (its log shows `TLS posture: sslmode=verify-full`).
- **Token lifetime**: the token is valid for 15 minutes, and it is used only when a connection is authenticated. The server gives its pool a 14-minute expiry (`expiry_min=14`). A SELECT sent 16 minutes after startup succeeded: the log showed `pool-1 expired`, `Retrieving IAM auth token`, `pool-2 initialized`, and that response took 2.4 seconds (normally 0.04). The AWS credentials the server runs with must still be valid at that point.
- **Who can assume the role**: `role_create.sh` trusts the IAM user who ran it, or the whole account if you ran it from a role session. In production, set the trust to the role where the agent runs (EC2, ECS, and so on).
- **What the role cannot do**: reading the master user's secret failed with `AccessDeniedException`, and `rds-data:ExecuteStatement` was denied.
- **`rds:DescribeDBInstances`**: not in the policy. Without it the server writes one WARNING and continues. To remove the warning, allow it on the instance ARN (the cluster ARN did not remove it).
- **KMS**: if the user-name secret uses a key you manage, the role also needs `kms:Decrypt` on that key. The lab uses the default key.
- **Comparison with the master user**: the same UPDATE through a write-enabled server that used the master user's secret and the Data API succeeded (120 to 121). This is what the read-only user prevents.

## Audit

- Connections with IAM DB authentication are not recorded in CloudTrail (documented limitations). Failures can go to CloudWatch Logs as `iam-db-auth-error` ([troubleshooting page](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/UsingWithRDS.IAMDBAuth.Troubleshooting.html)).
- `SHOW log_statement` returned `none` on this cluster, so SELECT statements are not logged. To trace which agent ran which SQL, enable `log_statement` or `pgaudit` in the parameter group, and map one IAM role to one database user per agent.

## Not tested

- Functions and views brought in by extensions (`pg_extension` had only `plpgsql` here), and revoking EXECUTE on built-in functions such as `lo_creat`
- Databases upgraded from PostgreSQL 14 or earlier, where `PUBLIC` may still have CREATE on the `public` schema
- Connections through RDS Proxy, or through any path other than a direct connection to the cluster endpoint
- Multi-AZ clusters, reader endpoints, failover, and Aurora Global Database
- `pgaudit` and the content of the logs after enabling `log_statement`
- Row-level security, column-level grants, and several agents with one database user each
- A customer managed KMS key on the secret
- Long sessions with expiring temporary credentials (I checked one pool rebuild at 16 minutes, with valid credentials)
- MCP server versions other than 1.2.4 (1.2.3 failed on the first SQL with this connection method), and RDS for PostgreSQL
- Load: many concurrent agents, connection limits above 0, and the memory needed in practice
