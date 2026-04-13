#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# monitoring-setup.sh
# Creates CloudWatch Log Groups and Container Insights for Brain Tasks App
# Run once after EKS cluster is created.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
EKS_CLUSTER="${EKS_CLUSTER:-brain-tasks-eks}"
RETENTION_DAYS=30

echo "=== Creating CloudWatch Log Groups ==="

aws logs create-log-group \
  --log-group-name "/aws/eks/${EKS_CLUSTER}/application"  \
  --region "$AWS_REGION" 2>/dev/null || echo "Already exists"

aws logs create-log-group \
  --log-group-name "/aws/eks/${EKS_CLUSTER}/dataplane"    \
  --region "$AWS_REGION" 2>/dev/null || echo "Already exists"

aws logs create-log-group \
  --log-group-name "/aws/codebuild/brain-tasks-app"       \
  --region "$AWS_REGION" 2>/dev/null || echo "Already exists"

# Set retention on all groups
for GROUP in \
  "/aws/eks/${EKS_CLUSTER}/application" \
  "/aws/eks/${EKS_CLUSTER}/dataplane"   \
  "/aws/codebuild/brain-tasks-app"; do
  aws logs put-retention-policy \
    --log-group-name "$GROUP" \
    --retention-in-days "$RETENTION_DAYS" \
    --region "$AWS_REGION"
  echo "Retention set: $GROUP → ${RETENTION_DAYS} days"
done

echo "=== Enabling EKS Container Insights ==="
aws eks update-cluster-config \
  --region "$AWS_REGION" \
  --name "$EKS_CLUSTER" \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'

echo "=== Deploying CloudWatch Agent to EKS (Container Insights) ==="
ClusterName=$EKS_CLUSTER
RegionName=$AWS_REGION
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'

curl -s https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml \
  | sed "s/{{cluster_name}}/${ClusterName}/;s/{{region_name}}/${RegionName}/;s/{{http_server_toggle}}/On/;s/{{http_server_port}}/${FluentBitHttpPort}/;s/{{read_from_head}}/${FluentBitReadFromHead}/" \
  | kubectl apply -f -

echo ""
echo "✅ CloudWatch monitoring configured!"
echo "   Log Groups:"
echo "     • /aws/eks/${EKS_CLUSTER}/application"
echo "     • /aws/eks/${EKS_CLUSTER}/dataplane"
echo "     • /aws/codebuild/brain-tasks-app"
echo ""
echo "   View logs:"
echo "     aws logs tail /aws/eks/${EKS_CLUSTER}/application --follow --region ${AWS_REGION}"
