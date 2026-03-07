# Architecture — Phase 1: Infrastructure

## Overview

```
┌────────────────────────────────────────────────────────┐
│  Windows 11 Host                                       │
│                                                        │
│  ┌────────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │k8s-controller-1│  │ k8s-worker-1│  │ k8s-worker-2│  │
│  │192.168.56.10   │  │192.168.56.11│  │192.168.56.12│  │
│  │2vCPU  8GB      │  │4vCPU  24GB  │  │4vCPU  24GB  │  │
│  │64GB disk       │  │64GB disk    │  │64GB disk    │  │
│  │control-plane   │  │   worker    │  │   worker    │  │
│  └──────┬─────────┘  └──────┬──────┘  └──────┬──────┘  │
│         └───────────────────┴────────────────┘         │
│                   192.168.56.0/24                      │
│                   (VMware host-only)                   │
└────────────────────────────────────────────────────────┘
```

## Provisioning Sequence

1. Vagrant creates 3 VMs from `bento/ubuntu-22.04`
2. `common.sh` runs on **all nodes**:
   - Disables swap (required by kubelet)
   - Loads kernel modules: `overlay`, `br_netfilter`
   - Configures sysctl for bridge networking and IP forwarding
   - Installs `containerd` from Docker's apt repo
   - Configures containerd with `SystemdCgroup = true`
   - Installs `kubeadm`, `kubelet`, `kubectl` (version-pinned)
3. `master-init.sh` runs on `k8s-controller-1`:
   - `kubeadm init` with pod-network-cidr `10.244.0.0/16`
   - Installs Flannel CNI
   - Writes the join command to `/vagrant/join-command.sh` (shared via synced folder)
4. `worker-join.sh` runs on each worker:
   - Polls for `/vagrant/join-command.sh`
   - Executes the join command

## Networking

| Network         | CIDR            | Purpose                    |
|-----------------|-----------------|----------------------------|
| VM host-only    | 192.168.56.0/24 | VM-to-VM + host-to-VM      |
| Pod network     | 10.244.0.0/16   | Flannel inter-pod routing  |
| Service network | 10.96.0.0/12    | Kubernetes ClusterIP range |

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hypervisor | VMware Workstation Pro | Available on host; better performance and networking than VirtualBox |
| VM provisioner | Vagrant + vagrant-vmware-desktop | Reproducible, declarative, shareable — single `vagrant up` |
| Base OS | Ubuntu 22.04 LTS (bento box) | LTS stability; wide kubeadm support; familiar |
| K8s bootstrapper | kubeadm | Production-grade fidelity; exposes real control plane config; teaches actual K8s |
| Container runtime | containerd | Required default since K8s 1.24 (dockershim removed); minimal, correct |
| CNI | Flannel | Zero-config overlay network; easy to understand; swappable (Calico/Cilium) later |
| Join command sharing | Vagrant synced folder (`/vagrant`) | No extra tooling; master writes, workers read |
| VM storage location | Default `.vagrant/` folder; overridable via `STACKLAYER_VM_DIR` env var | Works out of the box; power users can redirect to a dedicated drive |

## Key Tradeoffs Noted

- **kubeadm vs k3s/minikube**: kubeadm is more complex to bootstrap but reflects real
  production clusters (etcd, separate control plane components, real kubelet config).
  k3s would be faster to stand up but hides too much.

- **Flannel vs Calico**: Flannel is chosen for simplicity at this stage. Calico adds
  NetworkPolicy enforcement and BGP routing — better choices once we have workloads that
  need network isolation. Can be swapped by changing the CNI manifest URL in `master-init.sh`.

- **3 nodes vs 1**: A single-node cluster would work but misses the point. Multi-node
  exercises scheduler decisions, pod spreading, node affinity, and DaemonSet behavior —
  all important for production fidelity.

## What This Phase Does Not Include

Deliberately left for future phases with documented decisions:

- Ingress (no external traffic routing yet)
- Storage (no persistent volumes)
- GitOps (no ArgoCD/Flux)
- Observability (no Prometheus/Grafana)
- Developer tooling
