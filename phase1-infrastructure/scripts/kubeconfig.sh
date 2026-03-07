#!/usr/bin/env bash
# kubeconfig.sh — Copy kubeconfig from master to ~/.kube/config on the host
# Run from the repo root: make kubeconfig

set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"

echo "Copying kubeconfig from master to ~/.kube/config..."
mkdir -p ~/.kube
cd phase1-infrastructure && vagrant ssh k8s-controller-1 -c \
  "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config
echo "Done. kubectl is ready — no environment variable needed."
