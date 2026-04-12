# 🚀 DevOps Project 1 – MindTrack CI/CD Pipeline

---

## 📌 Project Overview

This project demonstrates a **production-ready CI/CD pipeline** that automates the deployment of a containerized frontend application to Kubernetes on AWS.

The pipeline is fully automated:

👉 **Git Push → Build → Docker → ECR → EKS → Live Deployment**

---

## 📁 Project Structure

```text
DevOps_Project_1_MindTrack/
├── Brain-Tasks-App/
│   ├── Dockerfile
│   ├── README.md
│   ├── buildspec.yml
│   ├── dist/
│   │   ├── assets/
│   │   ├── index.html
│   │   └── vite.svg
│   ├── k8s/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── nginx.conf
│   └── scripts/
│       ├── eks-setup.sh
│       └── monitoring-setup.sh
└── README.md
```

---

## 🧰 Tech Stack

* GitHub (Source Code + Webhook)
* AWS CodeBuild (CI/CD)
* Amazon ECR (Container Registry)
* Amazon EKS (Kubernetes)
* Docker
* kubectl
* nginx (serving static files)

---

## ⚙️ Application Setup

* Frontend built using Vite/React
* Production build output: `/dist`
* Static files served via `nginx:alpine`

---

## 🐳 Docker Setup

### Build Docker Image Locally

```bash
cd Brain-Tasks-App
docker build -t brain-tasks-app .
docker run -d -p 3000:3000 brain-tasks-app brain-tasks-app:latest
```

Open:

```
http://172.31.97.154:3000
```

---

## 📦 Amazon ECR Setup

### Login to ECR

```bash
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com
```

### Tag & Push Image

```bash
docker tag brain-tasks-app:latest <account-id>.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-app:latest
docker push <account-id>.dkr.ecr.ap-south-1.amazonaws.com/brain-tasks-app:latest
```

---

## ☸️ Amazon EKS Setup

### Create Cluster

```bash
eksctl create cluster --name brain-tasks-eks --region ap-south-1
```

### Configure kubectl

```bash
aws eks update-kubeconfig --region ap-south-1 --name brain-tasks-eks
```

---

## 📦 Kubernetes Deployment

### Create Namespace

```bash
kubectl create namespace production
```

### Apply Configurations

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

---

### Verify Deployment

```bash
kubectl get pods -n production
kubectl get svc -n productioni
```

---

## 🌐 Access Application

```bash
kubectl get svc -n production
```

Open in browser:

```
http://a93e9e55bdde54b47878adfabcdaa7da-1339219107.ap-south-1.elb.amazonaws.com/
```

---

## 🔐 IAM & RBAC Configuration

Add CodeBuild role to `aws-auth` ConfigMap:

```yaml
- rolearn: <CODEBUILD_ROLE_ARN>
  username: codebuild
  groups:
    - system:masters
```

### Verify Access

```bash
kubectl auth can-i get deployments -n production --as=codebuild
```

---

## 🏗️ CI/CD Pipeline (CodeBuild)

### Pipeline Steps

1. Code pushed to GitHub
2. Webhook triggers CodeBuild
3. Docker image is built
4. Image pushed to ECR
5. Kubernetes deployment updated
6. New version goes live

---

## 📜 buildspec.yml Workflow

* Authenticate to ECR
* Build Docker image
* Tag with timestamp
* Push to ECR
* Update EKS deployment
* Monitor rollout

---

## 🔔 Webhook Automation

* GitHub webhook triggers build on every push
* Fully automated deployment

---

## 📊 Monitoring

### CodeBuild Logs

* Available in CloudWatch
* Tracks build & deployment steps

### Kubernetes Logs

```bash
kubectl logs <pod-name> -n production
```

---

## 🧪 Final Testing

1. Modify application code
2. Push to GitHub

### Expected:

* Build triggers automatically
* New image pushed
* Deployment updated
* Changes visible in browser

---

## 📸 Screenshots (Add Below)

### 🔹 CodeBuild Success

![CodeBuild](./screenshots/codebuild.png)

### 🔹 CloudWatch Logs

![CloudWatch](./screenshots/cloudwatch.png)

### 🔹 Pods Running

![Pods](./screenshots/pods.png)

### 🔹 Services

![Services](./screenshots/services.png)

### 🔹 Application Live

![App](./screenshots/app.png)

---

## 🌍 Live Application

```
http://a93e9e55bdde54b47878adfabcdaa7da-1339219107.ap-south-1.elb.amazonaws.com/
```

---

## 🧹 Cleanup

To avoid AWS charges:

```bash
eksctl delete cluster --name brain-tasks-eks --region ap-south-1
```

Also delete:

* ECR repository
* CodeBuild project
* CloudWatch logs (optional)

---

## 👨‍💻 Author

**MARIA FRANCIS D**

---

## 🎯 Outcome

A complete CI/CD pipeline:

```
GitHub → CodeBuild → Docker → ECR → EKS → Live App
```

Fully automated and production-ready 🚀

---

