#!/usr/bin/env bash
# check-prerequisites.sh — Verify Phase 1 and Phase 2 are installed
# Source this script at the top of any Phase 3+ install script:
#   source "${REPO_ROOT}/scripts/check-prerequisites.sh"

set -euo pipefail

echo "--- Checking prerequisites ---"

# Phase 1: cluster must be reachable
if ! kubectl get nodes &>/dev/null; then
  echo ""
  echo "ERROR: Kubernetes cluster is not reachable."
  echo "  Run 'make infra' to provision the cluster, or 'make start' if it is powered off."
  echo ""
  exit 1
fi

# Phase 2: platform namespaces must exist
for ns in ingress-nginx cert-manager metallb-system; do
  if ! kubectl get namespace "${ns}" &>/dev/null; then
    echo ""
    echo "ERROR: Phase 2 platform is not installed (namespace '${ns}' not found)."
    echo "  Run 'make platform' first."
    echo ""
    exit 1
  fi
done

echo "Prerequisites OK."
echo ""
