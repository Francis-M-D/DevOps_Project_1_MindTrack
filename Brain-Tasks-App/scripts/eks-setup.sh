#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# eks-setup.sh
# Creates the EKS cluster, ECR repository, and configures IAM for the
# Brain Tasks App deployment pipeline.
#
# Prerequisites:
#   • AWS CLI v2 configured with admin credentials
#   • eksctl installed  (https://eksctl.io)
#   • kubectl installed
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="brain-tasks-eks"
ECR_REPO="brain-tasks-app"
NODE_TYPE="t3.medium"
NODE_MIN=2
NODE_MAX=4
K8S_VERSION="1.29"

echo "=== Step 1: Create ECR Repository ==="
aws ecr create-repository \
  --repository-name "$ECR_REPO" \
  --region "$AWS_REGION" \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  2>/dev/null && echo "ECR repo created: $ECR_REPO" || echo "ECR repo already exists."

echo ""
echo "=== Step 2: Create EKS Cluster with eksctl ==="
cat <<EOF | eksctl create cluster -f -
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}
  version: "${K8S_VERSION}"

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
EOF

echo ""
echo "=== Step 3: Update kubeconfig ==="
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo ""
echo "=== Step 4: Verify cluster ==="
kubectl get nodes
kubectl cluster-info

echo ""
echo "=== Step 5: Install AWS Load Balancer Controller ==="
# IAM policy for LBC
curl -o /tmp/iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file:///tmp/iam-policy.json \
  2>/dev/null || echo "Policy already exists"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

eksctl create iamserviceaccount \
  --cluster="$CLUSTER_NAME" \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy" \
  --approve \
  --region "$AWS_REGION"

helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

echo ""
echo "=== Step 6: Create production namespace ==="
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✅ EKS setup complete!"
echo "   Cluster:    ${CLUSTER_NAME}"
echo "   Region:     ${AWS_REGION}"
echo "   ECR Repo:   ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
echo ""
echo "Next → push code to GitHub → CodePipeline will trigger the build & deploy."
