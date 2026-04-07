#!/bin/bash
set -euo pipefail

if ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubectl is not installed or not in PATH."
  exit 1
fi

echo "Creating/updating Kubernetes secrets in namespace: platform"

read -rsp "Enter PostgreSQL password: " POSTGRES_PASSWORD
echo
read -rsp "Enter MinIO root password: " MINIO_PASSWORD
echo

if [ -z "${POSTGRES_PASSWORD}" ] || [ -z "${MINIO_PASSWORD}" ]; then
  echo "Error: passwords cannot be empty."
  exit 1
fi

kubectl create namespace platform --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic postgres-secret \
  --from-literal=username=mealie \
  --from-literal=password="${POSTGRES_PASSWORD}" \
  -n platform \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic minio-secret \
  --from-literal=username=minioadmin \
  --from-literal=password="${MINIO_PASSWORD}" \
  -n platform \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secrets created/updated successfully."
echo "Created secrets:"
kubectl get secrets -n platform | grep -E 'postgres-secret|minio-secret' || true