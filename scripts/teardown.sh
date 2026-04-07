#!/bin/bash
set -euo pipefail

echo "Deleting training jobs..."
kubectl delete -f k8s/monthly-retrain-cronjob.yaml --ignore-not-found=true
kubectl delete -f k8s/nightly-eval-cronjob.yaml --ignore-not-found=true

echo "Deleting inference service..."
kubectl delete -f k8s/inference-deployment.yaml --ignore-not-found=true

echo "Deleting Mealie..."
kubectl delete -f k8s/mealie-deployment.yaml --ignore-not-found=true

echo "Deleting platform services..."
kubectl delete -f k8s/mlflow-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/minio-deployment.yaml --ignore-not-found=true
kubectl delete -f k8s/postgres-statefulset.yaml --ignore-not-found=true

echo "Deleting ingress..."
kubectl delete -f k8s/ingress.yaml --ignore-not-found=true

echo "Deleting namespaces..."
kubectl delete -f k8s/namespaces.yaml --ignore-not-found=true

echo "Teardown complete."