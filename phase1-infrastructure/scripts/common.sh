#!/usr/bin/env bash
# common.sh — Runs on ALL nodes (master + workers)
# Installs containerd, kubeadm, kubelet, kubectl
# Configures kernel and networking prerequisites

set -euo pipefail

KUBE_VERSION="${KUBE_VERSION:-1.31}"

echo "==> [common] Starting common node setup (Kubernetes ${KUBE_VERSION})"

# -------------------------------------------------------------------
# 1. /etc/hosts — give every node a resolvable hostname
# -------------------------------------------------------------------
echo "==> [common] Configuring /etc/hosts"
cat >> /etc/hosts <<EOF
${NODE_IPS}
EOF

# -------------------------------------------------------------------
# 2. Disable swap (kubelet requirement)
# -------------------------------------------------------------------
echo "==> [common] Disabling swap"
swapoff -a
# Persist across reboots
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# -------------------------------------------------------------------
# 3. Kernel modules required by containerd and Kubernetes networking
# -------------------------------------------------------------------
echo "==> [common] Loading kernel modules"
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# -------------------------------------------------------------------
# 4. sysctl — enable bridge networking and IP forwarding
# -------------------------------------------------------------------
echo "==> [common] Configuring sysctl"
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# -------------------------------------------------------------------
# 5. Install containerd from Docker's apt repo
# -------------------------------------------------------------------
echo "==> [common] Installing containerd"
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release apt-transport-https

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -qq
apt-get install -y -qq containerd.io

# Configure containerd to use systemd cgroup driver (required for kubeadm)
containerd config default | tee /etc/containerd/config.toml > /dev/null
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# -------------------------------------------------------------------
# 6. Install kubeadm, kubelet, kubectl
# -------------------------------------------------------------------
echo "==> [common] Installing kubeadm, kubelet, kubectl (${KUBE_VERSION})"

curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo \
  "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v${KUBE_VERSION}/deb/ /" \
  | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl

# Pin versions to prevent accidental upgrades
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet

echo "==> [common] Done."
