#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

echo "Deleting team workloads..."
kubectl delete -f k8s/training/nightly-eval-cronjob.yaml --ignore-not-found=true
kubectl delete -f k8s/training/monthly-retrain-cronjob.yaml --ignore-not-found=true
kubectl delete -f k8s/data/batch-compile-cronjob.yaml --ignore-not-found=true
kubectl delete -f k8s/data/feature-service.yaml --ignore-not-found=true
kubectl delete -f k8s/serving/inference-deployment.yaml --ignore-not-found=true

echo "Deleting Mealie..."
kubectl delete -f k8s/mealie-deployment.yaml --ignore-not-found=true
kubectl delete configmap mealie-runtime-config -n mealie --ignore-not-found=true

echo "Deleting platform services..."
kubectl delete -f k8s/mlflow-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/minio-init-job.yaml --ignore-not-found=true
kubectl delete -f k8s/minio-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/postgres-statefulset.yaml --ignore-not-found=true

echo "Deleting namespaces..."
kubectl delete -f k8s/namespaces.yaml --ignore-not-found=true

echo "Teardown complete."
