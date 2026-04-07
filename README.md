

# DevOps MLOps Platform (Kubernetes)

**Course:** ML Systems Design & Operations
**Team:** Bias & Variance
**Role:** DevOps (mx2431) – Mahima Mariah
**Project:** Personalized Recipe Recommendations for Mealie

---

## Overview

This repository contains Kubernetes-based Infrastructure-as-Code (IaC) for deploying an end-to-end MLOps platform on **Chameleon Cloud**.

All infrastructure is defined declaratively using Kubernetes YAML manifests, serving as Infrastructure-as-Code (IaC) and the single source of truth in Git.

The platform supports:

* Application hosting (Mealie)
* ML inference serving
* Experiment tracking (MLflow)
* Artifact storage (MinIO)
* Metadata storage (Postgres)
* Batch pipelines for evaluation and retraining

---

## Quick Start

To deploy the full system:

```
cd proj18-mlops-devops
bash scripts/bootstrap.sh
```

---

## Cluster Provisioning (IaC)

The Kubernetes cluster is provisioned on a Chameleon Cloud VM using **K3s**.

The `bootstrap.sh` script performs:

* Installation of K3s (lightweight Kubernetes)
* Configuration of `kubectl` for the user
* Setup of required system dependencies

This results in a fully functional Kubernetes cluster ready to deploy platform and application services.

---

## Deployment Steps

### Step 1: Create Namespaces

```
kubectl apply -f infrastructure/k8s/namespaces.yaml
```

### Step 2: Deploy Platform Services

```
kubectl apply -f infrastructure/k8s/postgres-statefulset.yaml
kubectl apply -f infrastructure/k8s/minio-deployment.yaml
kubectl apply -f infrastructure/k8s/mlflow-deployment.yaml
```

### Step 3: Deploy Application Services

```
kubectl apply -f infrastructure/k8s/mealie-deployment.yaml
kubectl apply -f infrastructure/k8s/inference-deployment.yaml
```

### Step 4: Deploy Batch Jobs

```
kubectl apply -f infrastructure/k8s/nightly-eval-cronjob.yaml
kubectl apply -f infrastructure/k8s/monthly-retrain-cronjob.yaml
```

---

## Deployment Order Rationale

Resources are deployed in the following order:

1. **Namespaces** → logical isolation of services
2. **Platform services** (Postgres, MinIO, MLflow) → foundational dependencies
3. **Application services** (Mealie, inference API) → depend on platform services
4. **Batch jobs** → depend on model/data infrastructure

This ensures all dependencies are available before application startup.

---

## Repository Structure

```
proj18-mlops-devops/
├── infrastructure/
│   └── k8s/          # Kubernetes manifests (deployments, services, PVCs, CronJobs)
├── scripts/          # Automation scripts (bootstrap, teardown, secrets, evidence)
├── README.md
```

---

## Services Deployed

### Platform Services

* **Postgres** → Metadata database (StatefulSet with persistent storage)
* **MinIO** → Object storage for ML artifacts
* **MLflow** → Experiment tracking and model registry

### Application Services

* **Mealie** → Recipe management application
* **Inference API** → ALS-based recommendation service

### Batch Jobs

* **nightly-eval** → Evaluates model performance (Recall@10, NDCG@10)
* **monthly-retrain** → Retrains ALS model using updated data

---

## Networking / Access

Services are exposed using **NodePort** for simplicity in the Chameleon Cloud environment.

K3s installs **Traefik** by default (ingress controller), but NodePort is used here for direct access.

### Example Endpoints

* Mealie UI → http://<VM_IP>:30090
* MLflow → http://<VM_IP>:30500
* MinIO Console → http://<VM_IP>:30901
* Inference API → http://<VM_IP>:30800

---

## Storage & Durability

* **MinIO** provides persistent object storage for MLflow artifacts
* **Postgres** is deployed as a StatefulSet with persistent volume claims
* **MLflow** stores artifacts and metadata on persistent storage
* No reliance on ephemeral container filesystems

This ensures all critical data persists across pod restarts.

---

## Secrets Management

Secrets are created dynamically using:

```
bash scripts/create-secrets.sh
```

* Credentials (DB, MinIO) are stored in Kubernetes Secrets
* No sensitive data is committed to Git
* `.gitignore` prevents accidental leakage

---

## Evidence Collection

To collect system validation evidence:

```
bash scripts/collect-evidence.sh
```

This captures:

* Pod status
* Resource usage (kubectl top)
* Service availability

---

## Teardown

To remove all deployed resources:

```
bash scripts/teardown.sh
```

---

## Notes

* Designed for **low-scale deployment** (~1–10 users)
* Resource allocations are based on observed usage in Chameleon
* Architecture is modular and can be extended with:

  * Horizontal scaling
  * Ingress-based routing
  * CI/CD pipelines

---


