#!/usr/bin/env bash
# install.sh — Install Phase 2 platform primitives
# Run from the repo root: make platform
# Requires: make kubeconfig to have been run first

set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
HELM_VALUES="${REPO_ROOT}/phase2-platform/helm-values"
MANIFESTS="${REPO_ROOT}/phase2-platform/manifests"

echo ""
echo "=== StackLayer — Phase 2 Platform Install ==="
echo ""

# -------------------------------------------------------------------
# Helm repos
# -------------------------------------------------------------------
echo "--- Adding Helm repos ---"
helm repo add metallb https://metallb.github.io/metallb --force-update
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update
echo ""

# -------------------------------------------------------------------
# MetalLB
# -------------------------------------------------------------------
echo "--- Installing MetalLB ---"
# To find the latest chart version: helm search repo metallb/metallb
helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system \
  --create-namespace \
  --version 0.14.9 \
  --values "${HELM_VALUES}/metallb-values.yaml" \
  --wait

echo "Waiting for MetalLB webhook to be ready..."
kubectl rollout status deployment/metallb-controller -n metallb-system --timeout=120s

echo "Applying MetalLB IP pool..."
kubectl apply -f "${MANIFESTS}/metallb-ippool.yaml"
echo "MetalLB ready."
echo ""

# -------------------------------------------------------------------
# ingress-nginx
# -------------------------------------------------------------------
echo "--- Installing ingress-nginx ---"
# To find the latest chart version: helm search repo ingress-nginx/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --version 4.12.1 \
  --values "${HELM_VALUES}/ingress-nginx-values.yaml" \
  --wait

echo "ingress-nginx ready."
echo ""

# -------------------------------------------------------------------
# cert-manager
# -------------------------------------------------------------------
echo "--- Installing cert-manager ---"
# To find the latest chart version: helm search repo jetstack/cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version 1.17.2 \
  --values "${HELM_VALUES}/cert-manager-values.yaml" \
  --wait

echo "Waiting for cert-manager webhook to be ready..."
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

echo "Applying ClusterIssuer..."
kubectl apply -f "${MANIFESTS}/clusterissuer.yaml"
echo "cert-manager ready."
echo ""

# -------------------------------------------------------------------
# local-path-provisioner
# -------------------------------------------------------------------
echo "--- Installing local-path-provisioner ---"
# To find the latest release: https://github.com/rancher/local-path-provisioner/releases
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml

echo "Waiting for local-path-provisioner to be ready..."
kubectl rollout status deployment/local-path-provisioner -n local-path-storage --timeout=120s

echo "Setting local-path as default StorageClass..."
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'

echo "local-path-provisioner ready."
echo ""

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
echo "--- Platform Status ---"
echo ""
echo "LoadBalancer services:"
kubectl get svc -A --field-selector spec.type=LoadBalancer 2>/dev/null || true
echo ""
echo "StorageClasses:"
kubectl get storageclass
echo ""
echo "=== Phase 2 Install COMPLETE ==="
echo ""
echo "Add to your Windows hosts file (C:\\Windows\\System32\\drivers\\etc\\hosts):"
echo "  192.168.56.200  stacklayer.local"
echo ""
