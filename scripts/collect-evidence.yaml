#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

OUT_DIR="evidence_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"

kubectl get nodes -o wide | tee "$OUT_DIR/get_nodes.txt"
kubectl get ns | tee "$OUT_DIR/get_namespaces.txt"
kubectl get pods -A -o wide | tee "$OUT_DIR/get_pods_all.txt"
kubectl get svc -A | tee "$OUT_DIR/get_services_all.txt"
kubectl get pvc -A | tee "$OUT_DIR/get_pvc_all.txt"
kubectl get cronjobs -A | tee "$OUT_DIR/get_cronjobs_all.txt"
kubectl get hpa -A | tee "$OUT_DIR/get_hpa_all.txt" || true
kubectl get events -A --sort-by=.lastTimestamp | tee "$OUT_DIR/get_events_all.txt" || true
kubectl top pods -A | tee "$OUT_DIR/top_pods_all.txt" || true
kubectl top nodes | tee "$OUT_DIR/top_nodes.txt" || true

for entry in \
  "platform app=postgres postgres" \
  "platform app=minio minio" \
  "platform app=mlflow mlflow" \
  "mealie app=mealie-app mealie" \
  "serving app=inference-api inference" \
  "data app=feature-service feature-service"
do
  NS=$(echo "$entry" | awk '{print $1}')
  LABEL=$(echo "$entry" | awk '{print $2}')
  NAME=$(echo "$entry" | awk '{print $3}')
  POD=$(kubectl get pod -n "$NS" -l "$LABEL" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "${POD}" ]; then
    kubectl describe pod "$POD" -n "$NS" | tee "$OUT_DIR/describe_${NAME}.txt"
    kubectl logs "$POD" -n "$NS" --tail=200 | tee "$OUT_DIR/logs_${NAME}.txt" || true
  fi
done

echo "Evidence collection complete."
echo "Directory: $OUT_DIR"
