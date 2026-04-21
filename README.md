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
│  │  - model-promoter (*/6h)│                            │
│  └─────────────────────────┘                            │
└─────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
.
├── k8s/
│   ├── namespaces.yaml                  # platform, mealie, serving, data, training, monitoring
│   ├── postgres-statefulset.yaml        # PostgreSQL database (StatefulSet + PVC)
│   ├── minio-deployment.yaml            # MinIO object storage
│   ├── minio-init-job.yaml              # MinIO bucket initialization
│   ├── mlflow-deployment.yaml           # MLflow experiment tracking
│   ├── mealie-deployment.yaml           # Mealie recipe manager
│   ├── model-promoter-cronjob.yaml      # Automated model promotion (staging→canary→prod)
│   ├── batch-compile-cronjob.yaml       # Batch dataset compilation CronJob
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
cd proj18-mlops-devops

bash scripts/bootstrap.sh
```

This will:
1. Create all namespaces
2. Create Kubernetes secrets (prompts for credentials)
3. Deploy PostgreSQL, MinIO, MLflow
4. Deploy Mealie
5. Deploy serving, data, and training workloads
6. Print all service URLs

### Deployment Order

Resources are deployed in the following order:

1. **Namespaces** → logical isolation of services
2. **Secrets** → credentials for all services
3. **Platform services** (Postgres, MinIO, MLflow) → foundational dependencies
4. **Application services** (Mealie, Inference API) → depend on platform services
5. **Batch jobs & CronJobs** → depend on model/data infrastructure
6. **Monitoring** → Prometheus, Grafana, Alertmanager

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
| Inference API | `http://<NODE_IP>:30800` | — |
| Prometheus | `http://<NODE_IP>:30091` | — |
| Grafana | `http://<NODE_IP>:30300` | admin / admin123 |
| Alertmanager | `http://<NODE_IP>:30903` | — |

---

## ML Pipeline

### Data
- **Feature Service** (`data` namespace): Continuously serves features from MinIO `feature-store` bucket
- **Batch Compile** (CronJob, 2am daily): Compiles training datasets from Mealie interaction data into MinIO `training-data` bucket with train/val split and metadata manifest

### Training
- **Monthly Retrain** (CronJob, 1st of month, 4am): Trains ALS model, logs to MLflow, promotes to Production if `NDCG@10 >= threshold`
- **Nightly Eval** (CronJob, 3am daily): Validates data presence, model artifact, and inference API health. Logs results to MLflow `nightly-eval` experiment

### Model Promotion
- **Model Promoter** (CronJob, every 6 hours): Reads the latest nightly eval results from MLflow and automatically promotes models through the pipeline:
  - `staging` → `canary` → `production`
  - If inference API is unhealthy, automatically **rolls back** production to the last known good backup
  - Promotion only happens if eval metrics pass all quality gates

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

## Storage & Durability

- **MinIO** provides persistent object storage for MLflow artifacts and training data
- **Postgres** is deployed as a StatefulSet with persistent volume claims
- **MLflow** stores artifacts and metadata on persistent storage
- No reliance on ephemeral container filesystems

---

## Secrets Management

Secrets are created dynamically using:

```bash
bash scripts/create-secrets.sh
```

- Credentials (DB, MinIO) are stored in Kubernetes Secrets
- No sensitive data is committed to Git
- `.gitignore` prevents accidental leakage

---

## Evidence Collection

To collect system validation evidence:

```bash
bash scripts/collect-evidence.sh
```

This captures pod status, resource usage, service availability, and logs for all components.

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
