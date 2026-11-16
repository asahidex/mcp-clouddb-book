#!/usr/bin/env bash
# 9. Clean up (agent role if created, secret, instance, cluster, security group) and check that nothing is left. Keeps going if a step fails.
set -uo pipefail; cd "$(dirname "$0")"; source ./env.sh
# If role_create.sh was used, delete the agent role first (needs IAM permissions).
[ -f role_policy.json ] && bash ./role_delete.sh
aws secretsmanager delete-secret --secret-id "$RO_SECRET" --force-delete-without-recovery >/dev/null
aws rds delete-db-instance --db-instance-identifier "$INSTANCE" --skip-final-snapshot >/dev/null
aws rds wait db-instance-deleted --db-instance-identifier "$INSTANCE"
aws rds delete-db-cluster --db-cluster-identifier "$CLUSTER" --skip-final-snapshot >/dev/null
while aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER" >/dev/null 2>&1; do sleep 15; done
SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values="$SG_NAME" --query 'SecurityGroups[0].GroupId' --output text)
for i in 1 2 3 4 5 6; do aws ec2 delete-security-group --group-id "$SG" && break; sleep 60; done
echo "--- Leftover check (done if every line is [])"
aws rds describe-db-clusters  --query "DBClusters[?DBClusterIdentifier=='$CLUSTER'].DBClusterIdentifier" --output json
aws rds describe-db-instances --query "DBInstances[?DBInstanceIdentifier=='$INSTANCE'].DBInstanceIdentifier" --output json
aws secretsmanager list-secrets --include-planned-deletion --query "SecretList[?Name=='$RO_SECRET'].Name" --output json
aws ec2 describe-security-groups --filters Name=group-name,Values="$SG_NAME" --query 'SecurityGroups[].GroupId' --output json
