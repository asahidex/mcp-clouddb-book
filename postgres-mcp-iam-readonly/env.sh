# Shared variables. Every script sources this file first.
# If credentials come from environment variables (for example, temporary credentials from AssumeRole), do not set a profile.
if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then export AWS_PROFILE=${AWS_PROFILE:-<profile>}; fi
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-ap-northeast-1}
export CLUSTER=${CLUSTER:-cbsr2-iam}
export INSTANCE=${INSTANCE:-cbsr2-iam-1}
export SG_NAME=${SG_NAME:-cbsr2-iam-sg}
export DB_NAME=${DB_NAME:-appdb}
export RO_USER=${RO_USER:-mcp_readonly}
export RO_SECRET=${RO_SECRET:-cbsr2/mcp_readonly}
export MCP_VERSION=${MCP_VERSION:-1.2.4}
