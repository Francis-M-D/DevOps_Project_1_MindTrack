#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# eks-setup.sh (CLEAN VERSION)
# Creates EKS cluster, enables OIDC, sets up ECR, and prepares namespace
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="brain-tasks-eks"
ECR_REPO="brain-tasks-app"
NODE_TYPE="t3.small"
NODE_MIN=2
NODE_MAX=4
K8S_VERSION="1.30"

echo "=== Step 1: Create ECR Repository ==="
aws ecr create-repository \
  --repository-name "$ECR_REPO" \
  --region "$AWS_REGION" \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  2>/dev/null && echo "ECR repo created: $ECR_REPO" || echo "ECR repo already exists."

echo ""
echo "=== Step 2: Create EKS Cluster (OIDC ENABLED) ==="

cat <<EOF | eksctl create cluster -f -
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}
  version: "${K8S_VERSION}"

iam:
  withOIDC: true

managedNodeGroups:
  - name: brain-tasks-nodes
    instanceType: ${NODE_TYPE}
    minSize: ${NODE_MIN}
    maxSize: ${NODE_MAX}
    desiredCapacity: ${NODE_MIN}
    volumeSize: 20
    ssh:
      allow: false
    labels:
      role: worker
    tags:
      app: brain-tasks-app
      environment: production
    iam:
      withAddonPolicies:
        autoScaler: true
        cloudWatch: true
        ebs: true

cloudWatch:
  clusterLogging:
    enableTypes: ["*"]

addons:
  - name: vpc-cni
  - name: kube-proxy
  - name: coredns

EOF

echo ""
echo "=== Step 3: Update kubeconfig ==="
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo ""
echo "=== Step 4: Verify cluster ==="
kubectl get nodes
kubectl cluster-info

echo ""
echo "=== Step 5: Create production namespace ==="
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=== Step 6: Verify OIDC ==="
aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.identity.oidc.issuer" \
  --output text

echo ""
echo "✅ EKS setup complete!"
echo "   Cluster:    ${CLUSTER_NAME}"
echo "   Region:     ${AWS_REGION}"
echo "   ECR Repo:   $(aws sts get-caller-identity --query Account --output text).dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
