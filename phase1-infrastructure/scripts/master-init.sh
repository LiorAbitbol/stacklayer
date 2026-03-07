#!/usr/bin/env bash
# master-init.sh — Runs on k8s-controller-1 ONLY
# Initialises the control plane with kubeadm, installs Flannel CNI,
# and exports the worker join command to /vagrant/join-command.sh

set -euo pipefail

MASTER_IP="${MASTER_IP:-192.168.56.10}"
POD_CIDR="10.244.0.0/16"      # Flannel default
FLANNEL_MANIFEST="https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"

echo "==> [master] Initialising Kubernetes control plane"
echo "    Master IP : ${MASTER_IP}"
echo "    Pod CIDR  : ${POD_CIDR}"

# -------------------------------------------------------------------
# 1. kubeadm init
# -------------------------------------------------------------------
kubeadm init \
  --apiserver-advertise-address="${MASTER_IP}" \
  --apiserver-cert-extra-sans="${MASTER_IP}" \
  --pod-network-cidr="${POD_CIDR}" \
  --node-name="$(hostname)" \
  --ignore-preflight-errors=NumCPU,Mem

# -------------------------------------------------------------------
# 2. kubeconfig for root (used in this script) and vagrant user
# -------------------------------------------------------------------
echo "==> [master] Configuring kubeconfig"

# Root uses admin.conf directly (this script runs as root via Vagrant provisioner)
export KUBECONFIG=/etc/kubernetes/admin.conf

# vagrant user gets their own copy at ~/.kube/config (standard kubectl default)
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# -------------------------------------------------------------------
# 3. Install Flannel CNI
# -------------------------------------------------------------------
echo "==> [master] Installing Flannel CNI"
kubectl apply -f "${FLANNEL_MANIFEST}"

# -------------------------------------------------------------------
# 4. Wait for the control-plane node to become Ready
# -------------------------------------------------------------------
echo "==> [master] Waiting for control-plane node to become Ready..."
for i in $(seq 1 24); do
  STATUS=$(kubectl get node "$(hostname)" -o jsonpath='{.status.conditions[-1].type}' 2>/dev/null || echo "")
  if [ "${STATUS}" = "Ready" ]; then
    echo "==> [master] Control-plane node is Ready."
    break
  fi
  echo "    Attempt ${i}/24 — node not ready yet, waiting 10s..."
  sleep 10
done

# -------------------------------------------------------------------
# 5. Export join command to shared /vagrant folder
#    Workers read this file to join the cluster
# -------------------------------------------------------------------
echo "==> [master] Generating worker join command"
kubeadm token create --print-join-command > /vagrant/join-command.sh
chmod +x /vagrant/join-command.sh
echo "    Join command written to /vagrant/join-command.sh"

echo "==> [master] Done. Cluster info:"
kubectl get nodes
kubectl get pods -n kube-system
