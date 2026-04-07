#!/bin/bash
set -euo pipefail

OUT_DIR="evidence_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"

echo "Collecting Kubernetes evidence into $OUT_DIR ..."

echo "==> nodes"
kubectl get nodes -o wide | tee "$OUT_DIR/get_nodes.txt"

echo "==> all namespaces"
kubectl get ns | tee "$OUT_DIR/get_namespaces.txt"

echo "==> pods"
kubectl get pods -A -o wide | tee "$OUT_DIR/get_pods_all.txt"

echo "==> services"
kubectl get svc -A | tee "$OUT_DIR/get_services_all.txt"

echo "==> pvc"
kubectl get pvc -A | tee "$OUT_DIR/get_pvc_all.txt"

echo "==> cronjobs"
kubectl get cronjobs -A | tee "$OUT_DIR/get_cronjobs_all.txt"

echo "==> ingress"
kubectl get ingress -A | tee "$OUT_DIR/get_ingress_all.txt" || true

echo "==> describe mealie pod"
MEALIE_POD=$(kubectl get pod -n mealie -l app=mealie-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "${MEALIE_POD}" ]; then
  kubectl describe pod "$MEALIE_POD" -n mealie | tee "$OUT_DIR/describe_mealie_pod.txt"
  kubectl logs "$MEALIE_POD" -n mealie --tail=200 | tee "$OUT_DIR/logs_mealie.txt" || true
fi

echo "==> describe mlflow pod"
MLFLOW_POD=$(kubectl get pod -n platform -l app=mlflow -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "${MLFLOW_POD}" ]; then
  kubectl describe pod "$MLFLOW_POD" -n platform | tee "$OUT_DIR/describe_mlflow_pod.txt"
  kubectl logs "$MLFLOW_POD" -n platform --tail=200 | tee "$OUT_DIR/logs_mlflow.txt" || true
fi

echo "==> describe postgres pod"
POSTGRES_POD=$(kubectl get pod -n platform -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "${POSTGRES_POD}" ]; then
  kubectl describe pod "$POSTGRES_POD" -n platform | tee "$OUT_DIR/describe_postgres_pod.txt"
  kubectl logs "$POSTGRES_POD" -n platform --tail=200 | tee "$OUT_DIR/logs_postgres.txt" || true
fi

echo "==> describe minio pod"
MINIO_POD=$(kubectl get pod -n platform -l app=minio -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "${MINIO_POD}" ]; then
  kubectl describe pod "$MINIO_POD" -n platform | tee "$OUT_DIR/describe_minio_pod.txt"
  kubectl logs "$MINIO_POD" -n platform --tail=200 | tee "$OUT_DIR/logs_minio.txt" || true
fi

echo "==> describe inference pod"
INFER_POD=$(kubectl get pod -n platform -l app=inference-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "${INFER_POD}" ]; then
  kubectl describe pod "$INFER_POD" -n platform | tee "$OUT_DIR/describe_inference_pod.txt"
  kubectl logs "$INFER_POD" -n platform --tail=200 | tee "$OUT_DIR/logs_inference.txt" || true
fi

echo "==> resource usage (pods)"
kubectl top pods -A | tee "$OUT_DIR/top_pods_all.txt" || true

echo "==> resource usage (nodes)"
kubectl top nodes | tee "$OUT_DIR/top_nodes.txt" || true

echo "==> events"
kubectl get events -A --sort-by=.lastTimestamp | tee "$OUT_DIR/get_events_all.txt" || true

echo "Evidence collection complete."
echo "Directory: $OUT_DIR"