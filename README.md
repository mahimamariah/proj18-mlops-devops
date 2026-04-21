# proj18 — Mealie Personalized Recipe Recommender
**Team:** Bias & Variance (proj18)  
**Course:** ML Systems Design and Operations  
**Deployment:** Chameleon Cloud — Kubernetes (k3s)

---

## Overview

This repository contains the infrastructure, deployment manifests, and operational scripts for a personalized recipe recommendation system built on top of [Mealie](https://github.com/mealie-recipes/mealie) — an open-source recipe manager.

The system uses ALS (Alternating Least Squares) collaborative filtering to rank recipes in a user's personal Mealie library by predicted preference. The full ML pipeline — data collection, feature engineering, training, evaluation, serving, and monitoring — runs on a single-node Kubernetes cluster on Chameleon Cloud.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Chameleon Cloud (proj18)                │
│                                                         │
│  ┌──────────┐   ┌──────────┐   ┌──────────────────┐   │
│  │  Mealie  │──▶│Inference │   │     MLflow        │   │
│  │  :30090  │   │  API     │   │     :30500        │   │
│  └──────────┘   │  :8000   │   └──────────────────┘   │
│                 └──────────┘                            │
│  ┌──────────┐   ┌──────────┐   ┌──────────────────┐   │
│  │ Postgres │   │  MinIO   │   │   Monitoring      │   │
│  │  :5432   │   │  :30900  │   │ Prometheus :30091 │   │
│  └──────────┘   └──────────┘   │ Grafana    :30300 │   │
│                                │ Alertmanager:30903│   │
│  ┌─────────────────────────┐   └──────────────────┘   │
│  │     CronJobs            │                            │
│  │  - nightly-eval (3am)   │                            │
│  │  - monthly-retrain (1st)│                            │
│  │  - batch-compile (2am)  │                            │
│  └─────────────────────────┘                            │
└─────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
.
├── k8s/
│   ├── namespaces.yaml                  # platform, mealie, serving, data, training, monitoring
│   ├── postgres-statefulset.yaml        # PostgreSQL database
│   ├── minio-deployment.yaml            # MinIO object storage
│   ├── minio-init-job.yaml              # MinIO bucket initialization
│   ├── mlflow-deployment.yaml           # MLflow experiment tracking
│   ├── mealie-deployment.yaml           # Mealie recipe manager
│   ├── data/
│   │   ├── feature-service.yaml         # Feature engineering service
│   │   └── batch-compile-cronjob.yaml   # Nightly batch data compilation
│   ├── serving/
│   │   └── inference-deployment.yaml    # ALS inference API + HPA
│   ├── training/
│   │   ├── nightly_eval.yaml            # Nightly model evaluation CronJob
│   │   └── monthly-retrain-cronjob.yaml # Monthly model retraining CronJob
│   └── monitoring/
│       ├── monitoring-namespace.yaml
│       ├── prometheus-rbac.yaml
│       ├── prometheus-configmap.yaml    # Scrape configs + alert rules
│       ├── prometheus-deployment.yaml
│       ├── alertmanager-configmap.yaml
│       ├── alertmanager-deployment.yaml
│       ├── grafana-configmap.yaml       # Prometheus datasource
│       ├── grafana-deployment.yaml
│       ├── kube-state-metrics-rbac.yaml
│       ├── kube-state-metrics.yaml
│       └── feature-service-hpa.yaml    # HPA for feature-service
├── scripts/
│   ├── bootstrap.sh                     # Full system bootstrap
│   ├── create-secrets.sh                # Kubernetes secrets setup
│   ├── collect-evidence.sh              # Evidence collection script
│   └── teardown.sh                      # Full system teardown
├── SAFEGUARDING.md                      # Safeguarding plan
└── README.md
```

---

## Namespaces

| Namespace | Purpose |
|---|---|
| `platform` | PostgreSQL, MinIO, MLflow |
| `mealie` | Mealie recipe manager |
| `serving` | Inference API |
| `data` | Feature service, batch compile |
| `training` | Nightly eval, monthly retrain |
| `monitoring` | Prometheus, Grafana, Alertmanager |

---

## Quick Start

### Prerequisites
- Kubernetes cluster (k3s on Chameleon Cloud)
- `kubectl` configured
- Docker Hub credentials (for private images)

### Deploy the full system

```bash
git clone https://github.com/mahimamariah/proj18-mlops-devops.git
cd proj18-mlops-devops/infrastructure

bash scripts/bootstrap.sh
```

This will:
1. Create all namespaces
2. Create Kubernetes secrets (prompts for credentials)
3. Deploy PostgreSQL, MinIO, MLflow
4. Deploy Mealie
5. Deploy serving, data, and training workloads
6. Print all service URLs

### Tear down

```bash
bash scripts/teardown.sh
```

---

## Services

| Service | URL | Credentials |
|---|---|---|
| Mealie | `http://<NODE_IP>:30090` | admin / (set on first login) |
| MLflow | `http://<NODE_IP>:30500` | — |
| MinIO UI | `http://<NODE_IP>:30901` | (set during bootstrap) |
| Prometheus | `http://<NODE_IP>:30091` | — |
| Grafana | `http://<NODE_IP>:30300` | admin / admin123 |
| Alertmanager | `http://<NODE_IP>:30903` | — |

---

## ML Pipeline

### Data
- **Feature Service** (`data` namespace): Continuously serves features from MinIO `feature-store` bucket
- **Batch Compile** (CronJob, 2am daily): Compiles training datasets from Mealie interaction data into MinIO `training-data` bucket

### Training
- **Monthly Retrain** (CronJob, 1st of month, 4am): Trains ALS model, logs to MLflow, promotes to Production if `NDCG@10 >= threshold`
- **Nightly Eval** (CronJob, 3am daily): Validates data presence, model artifact, and inference API health. Logs results to MLflow `nightly-eval` experiment

### Serving
- **Inference API** (`serving` namespace): Serves ALS recommendations via `/recommend` endpoint
- **HPA**: Auto-scales inference-api (1–3 replicas) on CPU > 70%

---

## Monitoring

- **Prometheus** scrapes kube-state-metrics every 15s
- **Grafana** dashboards connected to Prometheus datasource
- **Alertmanager** handles alert routing

### Alert Rules
| Alert | Condition | Severity |
|---|---|---|
| PodCrashLooping | >2 restarts in 10min | warning |
| DeploymentReplicasUnavailable | unavailable replicas > 0 for 10min | critical |
| StatefulSetReplicasUnavailable | ready < total for 10min | critical |
| FailedCronJob | job failure detected | warning |
| HPAAtMaxReplicas | HPA at max replicas for 10min | warning |

### Auto-scaling
- `inference-api`: 1–3 replicas, CPU > 70%
- `feature-service`: 1–3 replicas, CPU > 70% or memory > 80%

---

## Safeguarding

See [SAFEGUARDING.md](./SAFEGUARDING.md) for the full safeguarding plan covering fairness, transparency, privacy, robustness, and accountability.

---

## Team

| Role | Member |
|---|---|
| DevOps / Platform | Mahima Mariah |
| Data | Bryce |
| Training | Shashwat |
| Serving | Sharvin |

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


