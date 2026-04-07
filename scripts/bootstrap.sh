#!/bin/bash
set -euo pipefail

echo "=== Bootstrap starting ==="

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed or not in PATH."
  exit 1
fi

if [ ! -d "k8s" ]; then
  echo "Error: run this script from the infrastructure/ directory so ./k8s exists."
  exit 1
fi

if [ ! -f "scripts/create-secrets.sh" ]; then
  echo "Error: scripts/create-secrets.sh not found."
  exit 1
fi

echo "=== Verifying Kubernetes connectivity ==="
kubectl get nodes

echo "=== Applying namespaces ==="
kubectl apply -f k8s/namespaces.yaml

echo "=== Creating secrets ==="
chmod +x scripts/create-secrets.sh
./scripts/create-secrets.sh

echo "=== Deploying platform services ==="
kubectl apply -f k8s/postgres-statefulset.yaml
kubectl apply -f k8s/minio-deployment.yaml
kubectl apply -f k8s/mlflow-deployment.yaml

echo "=== Deploying Mealie ==="
kubectl apply -f k8s/mealie-deployment.yaml

echo "=== Deploying inference API ==="
kubectl apply -f k8s/inference-deployment.yaml

echo "=== Deploying scheduled jobs ==="
kubectl apply -f k8s/nightly-eval-cronjob.yaml
kubectl apply -f k8s/monthly-retrain-cronjob.yaml

echo "=== Waiting briefly for resources to initialize ==="
sleep 10

echo "=== Current pods ==="
kubectl get pods -A -o wide

echo "=== Current services ==="
kubectl get svc -A

echo "=== Current PVCs ==="
kubectl get pvc -A

echo
echo "=== Bootstrap complete ==="
echo "Access your services using your Chameleon floating IP:"
echo "  Mealie:   http://<FLOATING_IP>:30090"
echo "  MLflow:   http://<FLOATING_IP>:30500"
echo "  MinIO:    http://<FLOATING_IP>:30901"
echo "  Inference health: http://<FLOATING_IP>:30800/health"
echo
echo "Note: Before running bootstrap, make sure you replaced REPLACE_WITH_FLOATING_IP in k8s/mealie-deployment.yaml."