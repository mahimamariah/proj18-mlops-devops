# DevOps MLOps Platform (Kubernetes)

Course: ML Systems Design & Operations
Team: Bias & Variance
Role: Devops (mx2431) Mahima Mariah
Project: Personalized recipe recommendations for Mealie
## Overview
This repository contains Kubernetes-based infrastructure (IaC) for deploying an ML platform on Chameleon Cloud.

## Repository Structure
- infrastructure/k8s/ → Kubernetes manifests
- scripts/ → automation scripts (bootstrap, teardown, secrets, evidence)

## Services Deployed
- MLflow (experiment tracking)
- MinIO (artifact storage)
- Postgres (metadata database)
- Mealie (application service)
- Inference API
- CronJobs:
  - nightly-eval
  - monthly-retrain

## Deployment Instructions
Run from infrastructure directory:
cd infrastructure
../scripts/bootstrap.sh

## Durability
- MinIO used for persistent artifact storage
- Postgres deployed as StatefulSet
- No reliance on ephemeral container storage

## Secrets
- Managed via create-secrets.sh
- No secrets committed to Git

## Evidence
To collect system evidence:
./scripts/collect-evidence.sh
