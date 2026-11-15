#!/usr/bin/env bash
# 1. Create a security group, an Aurora PostgreSQL cluster (Serverless v2, Data API, IAM DB auth), and the user-name secret.
set -euo pipefail; cd "$(dirname "$0")"; source ./env.sh
MYIP=$(curl -s https://checkip.amazonaws.com)
VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SG=$(aws ec2 create-security-group --group-name "$SG_NAME" --description "postgres-mcp lab" --vpc-id "$VPC" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 5432 --cidr "$MYIP/32" >/dev/null
# Pick the latest 17.x available in the Region (17.11 in ap-northeast-1 on 2026-11-11)
VER=$(aws rds describe-db-engine-versions --engine aurora-postgresql --query 'DBEngineVersions[].EngineVersion' --output text | tr '\t' '\n' | grep -E '^17\.' | sort -V | tail -1)
echo "engine version: $VER"
aws rds create-db-cluster --db-cluster-identifier "$CLUSTER" --engine aurora-postgresql --engine-version "$VER" \
  --master-username postgres --manage-master-user-password --database-name "$DB_NAME" \
  --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=2 --vpc-security-group-ids "$SG" \
  --backup-retention-period 1 --enable-http-endpoint --enable-iam-database-authentication >/dev/null
aws rds create-db-instance --db-instance-identifier "$INSTANCE" --db-cluster-identifier "$CLUSTER" \
  --engine aurora-postgresql --db-instance-class db.serverless --publicly-accessible >/dev/null
# IAM auth does not use the password, but 1.2.4 refuses to start without a password key, so store a dummy value.
RO_ARN=$(aws secretsmanager create-secret --name "$RO_SECRET" --secret-string "{\"username\":\"$RO_USER\",\"password\":\"unused\"}" --query ARN --output text)
aws rds wait db-instance-available --db-instance-identifier "$INSTANCE"
aws rds describe-db-clusters --db-cluster-identifier "$CLUSTER" \
  --query 'DBClusters[0].{arn:DBClusterArn,ep:Endpoint,master_secret:MasterUserSecret.SecretArn}' --output json | jq --arg ro "$RO_ARN" '. + {ro_secret: $ro}' > state.json
cat state.json
