# StackLayer

A locally reproducible lab environment that mirrors production Kubernetes infrastructure.
Built phase by phase — each phase is fully documented before the next begins.

## Goal

Run on **Windows 11 + VMware Workstation Pro**. Automated enough to tear down and rebuild
at will. Shareable with others who have similar setups.

## Phase 2 — Platform Primitives (current)

MetalLB, ingress-nginx, cert-manager, and local-path-provisioner installed on the Phase 1 cluster.

| Component              | Purpose                          | Access                      |
|------------------------|----------------------------------|-----------------------------|
| MetalLB (L2)           | LoadBalancer IPs                 | Pool: 192.168.56.200–220    |
| ingress-nginx          | HTTP/HTTPS ingress               | 192.168.56.200 (pinned)     |
| cert-manager           | TLS certificates (self-signed)   | ClusterIssuer: `selfsigned` |
| local-path-provisioner | Default StorageClass             | `local-path`                |

See [docs/phase2-architecture.md](docs/phase2-architecture.md) for design decisions.

---

## Phase 1 — Infrastructure

3 Ubuntu VMs provisioned by Vagrant, bootstrapped into a kubeadm Kubernetes cluster.

| Node             | IP            | Role          | vCPU | RAM   | Disk          |
|------------------|---------------|---------------|------|-------|---------------|
| k8s-controller-1 | 192.168.56.10 | control-plane | 2    | 8 GB  | 64 GB (default) |
| k8s-worker-1     | 192.168.56.11 | worker        | 4    | 24 GB | 64 GB (default) |
| k8s-worker-2     | 192.168.56.12 | worker        | 4    | 24 GB | 64 GB (default) |

**Total host resources required:** 10 vCPU, 56 GB RAM, ~192 GB disk

> **Note:** Disk resizing via `vm.disk` is disabled due to a bug in vagrant-vmware-desktop
> 3.0.5. All VMs use the bento/ubuntu-22.04 default (64 GB). Disks can be expanded manually
> in VMware Workstation after provisioning if needed.

See [docs/phase1-architecture.md](docs/phase1-architecture.md) for design decisions.
See [docs/prerequisites.md](docs/prerequisites.md) for host setup.
See [docs/architecture.md](docs/architecture.md) for the full architecture overview.

## Quick Start

### Prerequisites

See [docs/prerequisites.md](docs/prerequisites.md) for the full list. TL;DR:

1. VMware Workstation Pro (17+)
2. Vagrant (`winget install HashiCorp.Vagrant`)
3. vagrant-vmware-desktop plugin (`vagrant plugin install vagrant-vmware-desktop`)
4. kubectl (`winget install Kubernetes.kubectl`)
5. Helm (`winget install Helm.Helm`)
6. Git for Windows at default path (`winget install Git.Git`) — required by make targets

### Spin up the cluster

```powershell
make up
```

This will:
- Create 3 Ubuntu 22.04 VMs in VMware Workstation
- Install containerd, kubeadm, kubelet, kubectl on all nodes
- Run `kubeadm init` on the master, install Flannel CNI
- Join both worker nodes to the cluster

> **Note:** Vagrant stores VM files under `.vagrant/machines/` inside the project directory,
> not in VMware's default VM library path. The VMs will **not** appear automatically in the
> VMware Workstation UI. To register them manually: open VMware Workstation →
> **File → Open** → navigate to `.vagrant/machines/<node-name>/vmware_desktop/<uuid>/`
> and open the `.vmx` file. This is cosmetic only — the cluster works without registering them.

Copy kubeconfig to your host (writes to `~/.kube/config` — no env var needed):

```powershell
make kubeconfig
kubectl get nodes
```

Verify the cluster:

```powershell
make verify
```

### Install platform primitives (Phase 2)

```powershell
make platform
```

Add to your Windows hosts file (`C:\Windows\System32\drivers\etc\hosts`):

```
192.168.56.200  stacklayer.local
```

### Power the cluster on and off

Use Vagrant directly for day-to-day power management:

```powershell
cd phase1-infrastructure
vagrant halt    # graceful shutdown
vagrant up      # power back on (skips provisioning for existing VMs)
```

### Tear down

```powershell
make destroy
```

This will prompt for confirmation, then destroy all 3 VMs. VM disk files are deleted.
The `.vagrant/` folder (or your `STACKLAYER_VM_DIR`) can be removed manually afterward
if you want to reclaim the disk space fully.

To rebuild from scratch after destroying:

```powershell
make up
make kubeconfig
make verify
```

## Repository Structure

```
stacklayer/
├── Makefile
├── docs/
│   ├── prerequisites.md        # What to install on the host
│   ├── architecture.md         # High-level overview, links to phase docs
│   ├── phase1-architecture.md  # Phase 1 design decisions
│   └── phase2-architecture.md  # Phase 2 design decisions
├── phase1-infrastructure/
│   ├── Vagrantfile             # VM definitions
│   └── scripts/
│       ├── common.sh           # All nodes: containerd, kubeadm, kubelet, kubectl
│       ├── master-init.sh      # Control plane: kubeadm init + Flannel CNI
│       ├── worker-join.sh      # Workers: join cluster via shared join command
│       └── verify.sh           # Smoke test: nodes Ready, test pod
└── phase2-platform/
    ├── helm-values/
    │   ├── metallb-values.yaml
    │   ├── ingress-nginx-values.yaml
    │   └── cert-manager-values.yaml
    ├── manifests/
    │   ├── metallb-ippool.yaml  # IPAddressPool + L2Advertisement
    │   └── clusterissuer.yaml   # Self-signed ClusterIssuer
    └── scripts/
        └── install.sh           # Installs all Phase 2 components in order
```

## Networking

| CIDR            | Purpose              |
|-----------------|----------------------|
| 192.168.56.0/24 | VM host-only network |
| 10.244.0.0/16   | Pod network (Flannel) |
| 10.96.0.0/12    | Service network      |

## Design Principles

- **Reproducible**: `vagrant destroy && vagrant up` returns you to a clean cluster
- **Layered**: Each phase is designed and documented before the next begins
- **Shareable**: Vagrant + VMware Workstation Pro is the only host dependency

## Phases (planned)

Subsequent phases will be designed and documented as each previous phase is stable.
Decisions on tooling, patterns, and architecture will be made deliberately.
