# 🧠 Brain Tasks App – Production DevOps Pipeline

> **React SPA** served via **Nginx** · **Dockerized** · Deployed to **AWS EKS** via **CodePipeline + CodeBuild**

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Repository Structure](#repository-structure)
3. [Local Run (Port 3000)](#local-run-port-3000)
4. [Docker Setup](#docker-setup)
5. [AWS ECR – Container Registry](#aws-ecr--container-registry)
6. [AWS EKS – Kubernetes Setup](#aws-eks--kubernetes-setup)
7. [Kubernetes Manifests](#kubernetes-manifests)
8. [AWS CodeBuild](#aws-codebuild)
9. [AWS CodePipeline](#aws-codepipeline)
10. [CloudWatch Monitoring](#cloudwatch-monitoring)
11. [Pipeline Flow](#pipeline-flow)

---

## Architecture Overview

```
GitHub (push) ──► CodePipeline ──► CodeBuild ──► ECR ──► EKS (production ns)
                                                              │
                                                    AWS Network Load Balancer
                                                              │
                                                        Users (port 80)
```

| Layer | Technology |
|-------|-----------|
| App   | React (pre-built static dist) |
| Server | Nginx 1.25 Alpine |
| Container | Docker |
| Registry | AWS ECR |
| Orchestration | AWS EKS (Kubernetes 1.29) |
| CI/CD | AWS CodeBuild + CodePipeline |
| Monitoring | AWS CloudWatch + Container Insights |

---

## Repository Structure

```
Brain-Tasks-App/
├── dist/                        # Pre-built React production files
│   ├── index.html
│   ├── vite.svg
│   └── assets/
├── Dockerfile                   # Nginx serves dist/ on port 3000
├── nginx.conf                   # Custom Nginx config
├── .dockerignore
├── buildspec.yml                # AWS CodeBuild instructions
├── k8s/
│   ├── deployment.yaml          # Deployment + HPA
│   └── service.yaml             # LoadBalancer Service + Namespace
├── scripts/
│   ├── eks-setup.sh             # One-time EKS + ECR provisioning
│   └── monitoring-setup.sh     # CloudWatch log groups
└── .github/workflows/deploy.yml # Optional GitHub Actions pipeline
```

---

## Local Run (Port 3000)

```bash
git clone https://github.com/Vennilavanguvi/Brain-Tasks-App.git
cd Brain-Tasks-App

docker build -t brain-tasks-app:local .
docker run -d -p 3000:3000 --name brain-tasks brain-tasks-app:local

open http://localhost:3000
```

---

## Docker Setup

The Dockerfile uses **Nginx Alpine** to serve the pre-built `dist/` folder on port 3000.

```bash
# Build
docker build -t brain-tasks-app:1.0.0 .

# Smoke test
docker run --rm -d -p 3000:3000 --name smoke brain-tasks-app:1.0.0
curl -f http://localhost:3000/health && echo "OK"
docker stop smoke
```

---

## AWS ECR – Container Registry

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/brain-tasks-app"

# Create repo
aws ecr create-repository --repository-name brain-tasks-app \
  --region $AWS_REGION --image-scanning-configuration scanOnPush=true

# Login & push
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin \
    "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker tag brain-tasks-app:1.0.0 "${ECR_URI}:latest"
docker push "${ECR_URI}:latest"
```

---

## AWS EKS – Kubernetes Setup

```bash
# One-time cluster + LBC setup
chmod +x scripts/eks-setup.sh && ./scripts/eks-setup.sh

# Verify
kubectl get nodes
kubectl cluster-info
```

---

## Kubernetes Manifests

```bash
# Update ECR image reference
sed -i "s|<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>|${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}|g" \
  k8s/deployment.yaml

# Deploy
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml
kubectl rollout status deployment/brain-tasks-app -n production

# Get LoadBalancer DNS
kubectl get svc brain-tasks-app-svc -n production \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Get NLB ARN
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(DNSName,'brain-tasks')].LoadBalancerArn" \
  --output text
```

---

## AWS CodeBuild

**Create project settings:**
- Source: GitHub → `Brain-Tasks-App` repo
- Environment: Amazon Linux 2023, Standard image, **Privileged mode ON**
- Buildspec: use `buildspec.yml` from repo root
- CloudWatch Logs: `/aws/codebuild/brain-tasks-app`

**Environment variables:**

| Variable | Value |
|----------|-------|
| `AWS_REGION` | `us-east-1` |
| `ECR_REPO_NAME` | `brain-tasks-app` |
| `EKS_CLUSTER_NAME` | `brain-tasks-eks` |
| `K8S_NAMESPACE` | `production` |

---

## AWS CodePipeline

**Stages:**

| Stage | Provider | Config |
|-------|----------|--------|
| Source | GitHub v2 | Branch: `main`, webhook trigger |
| Build | CodeBuild | Project: `brain-tasks-app-build` |
| Deploy | (in buildspec) | `kubectl apply` in `post_build` phase |

---

## CloudWatch Monitoring

```bash
# Setup log groups + Container Insights
chmod +x scripts/monitoring-setup.sh && ./scripts/monitoring-setup.sh

# Tail build logs
aws logs tail /aws/codebuild/brain-tasks-app --follow

# Tail app logs
aws logs tail /aws/eks/brain-tasks-eks/application --follow
```

---

## Pipeline Flow

```
Git push to main
      │
      ▼
CodePipeline triggered (webhook)
      │
      ▼  CodeBuild
   ✓  ECR login
   ✓  docker build + smoke test
   ✓  docker push (sha-tag + latest)
   ✓  kubectl apply (service + deployment)
   ✓  kubectl rollout status
      │
      ▼
EKS – 2 Pods, Rolling update, HPA (2–6 replicas)
      │
      ▼
AWS NLB → port 80 → Nginx:3000 → React SPA
      │
      ▼
CloudWatch Logs (build + app logs, 30-day retention)
```
