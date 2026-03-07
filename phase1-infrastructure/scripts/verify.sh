#!/usr/bin/env bash
# verify.sh — Smoke test for the Phase 1 cluster
# Run from the host: make verify
# Requires: make kubeconfig to have been run first (writes to ~/.kube/config)

set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"

echo ""
echo "=== StackLayer — Phase 1 Cluster Verification ==="
echo ""

# -------------------------------------------------------------------
# Nodes
# -------------------------------------------------------------------
echo "--- Nodes ---"
kubectl get nodes -o wide
echo ""

# Check all nodes are Ready
# { grep ... || true; } prevents grep's exit code 1 (no matches) from
# triggering set -e when all nodes are healthy.
NOT_READY=$(kubectl get nodes --no-headers | { grep -v " Ready " || true; } | wc -l)
if [ "${NOT_READY}" -gt 0 ]; then
  echo "ERROR: ${NOT_READY} node(s) are not Ready."
  kubectl get nodes --no-headers | { grep -v " Ready " || true; }
  exit 1
fi
echo "All nodes are Ready."
echo ""

# -------------------------------------------------------------------
# System pods
# -------------------------------------------------------------------
echo "--- kube-system pods ---"
kubectl get pods -n kube-system -o wide
echo ""

NOT_RUNNING=$(kubectl get pods -n kube-system --no-headers \
  | { grep -Ev "Running|Completed" || true; } | wc -l)
if [ "${NOT_RUNNING}" -gt 0 ]; then
  echo "WARNING: Some kube-system pods are not Running/Completed:"
  kubectl get pods -n kube-system --no-headers | { grep -Ev "Running|Completed" || true; }
fi

# -------------------------------------------------------------------
# Quick workload test
# -------------------------------------------------------------------
echo "--- Deploying test pod (nginx) ---"
kubectl run nginx-test --image=nginx --restart=Never --timeout=60s 2>/dev/null || true
kubectl wait pod/nginx-test --for=condition=Ready --timeout=60s
kubectl delete pod nginx-test --now 2>/dev/null || true
echo "Test pod created and deleted successfully."
echo ""

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo "=== Verification PASSED ==="
echo ""
