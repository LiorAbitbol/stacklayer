#!/usr/bin/env bash
# install.sh — Install Phase 3 GitOps (ArgoCD)
# Run from the repo root: make gitops
# Requires: make platform to have been run first

set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
HELM_VALUES="${REPO_ROOT}/phase3-gitops/helm-values"
MANIFESTS="${REPO_ROOT}/phase3-gitops/manifests"

echo ""
echo "=== StackLayer — Phase 3 GitOps Install ==="
echo ""

# -------------------------------------------------------------------
# Prerequisites
# -------------------------------------------------------------------
source "${REPO_ROOT}/scripts/check-prerequisites.sh"

# -------------------------------------------------------------------
# Helm repo
# -------------------------------------------------------------------
echo "--- Adding Helm repo ---"
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update
echo ""

# -------------------------------------------------------------------
# ArgoCD
# -------------------------------------------------------------------
echo "--- Installing ArgoCD ---"
# To find the latest chart version: helm search repo argo/argo-cd
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 7.8.23 \
  --values "${HELM_VALUES}/argocd-values.yaml" \
  --wait

echo "Waiting for ArgoCD server to be ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=180s

echo "Applying ArgoCD ingress..."
kubectl apply -f "${MANIFESTS}/argocd-ingress.yaml"
echo "ArgoCD ready."
echo ""

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo "--- ArgoCD Access ---"
echo ""
echo "  URL:      https://argocd.stacklayer.local"
echo "  Username: admin"
echo "  Password: stacklayer"
echo ""
echo "Add to your Windows hosts file (C:\\Windows\\System32\\drivers\\etc\\hosts):"
echo "  192.168.56.200  argocd.stacklayer.local"
echo ""
echo "=== Phase 3 Install COMPLETE ==="
echo ""
