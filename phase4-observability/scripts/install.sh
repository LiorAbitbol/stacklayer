#!/usr/bin/env bash
# install.sh — Install Phase 4 Observability (kube-prometheus-stack)
# Run from the repo root: make observability
# Requires: make platform to have been run first

set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
HELM_VALUES="${REPO_ROOT}/phase4-observability/helm-values"
MANIFESTS="${REPO_ROOT}/phase4-observability/manifests"

echo ""
echo "=== StackLayer — Phase 4 Observability Install ==="
echo ""

# -------------------------------------------------------------------
# Prerequisites
# -------------------------------------------------------------------
source "${REPO_ROOT}/scripts/check-prerequisites.sh"

# -------------------------------------------------------------------
# Helm repo
# -------------------------------------------------------------------
echo "--- Adding Helm repo ---"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo update
echo ""

# -------------------------------------------------------------------
# kube-prometheus-stack
# -------------------------------------------------------------------
echo "--- Installing kube-prometheus-stack ---"
# To find the latest chart version: helm search repo prometheus-community/kube-prometheus-stack
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --version 70.4.2 \
  --values "${HELM_VALUES}/kube-prometheus-stack-values.yaml" \
  --wait \
  --timeout 10m

echo "Applying Grafana ingress..."
kubectl apply -f "${MANIFESTS}/grafana-ingress.yaml"
echo "kube-prometheus-stack ready."
echo ""

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo "--- Grafana Access ---"
echo ""
echo "  URL:      https://grafana.stacklayer.local"
echo "  Username: admin"
echo "  Password: stacklayer"
echo ""
echo "Add to your Windows hosts file (C:\\Windows\\System32\\drivers\\etc\\hosts):"
echo "  192.168.56.200  grafana.stacklayer.local"
echo ""
echo "=== Phase 4 Install COMPLETE ==="
echo ""
