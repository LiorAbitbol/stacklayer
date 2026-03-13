# StackLayer

A locally reproducible lab environment that mirrors production Kubernetes infrastructure.
Built phase by phase — each phase is fully documented before the next begins.

**Host:** Windows 11 + VMware Workstation Pro. Automated enough to tear down and rebuild
at will. Shareable with others who have similar setups.

## Documentation

- [docs/prerequisites.md](docs/prerequisites.md) — what to install on the host
- [docs/architecture.md](docs/architecture.md) — full architecture overview and phase map
- [docs/tutorials/](docs/tutorials/) — how-to guides for deploying apps to the cluster

## Quick Start

### Prerequisites

See [docs/prerequisites.md](docs/prerequisites.md) for the full list. TL;DR:

1. VMware Workstation Pro (17+)
2. Vagrant (`winget install HashiCorp.Vagrant`)
3. vagrant-vmware-desktop plugin (`vagrant plugin install vagrant-vmware-desktop`)
4. kubectl (`winget install Kubernetes.kubectl`)
5. Helm (`winget install Helm.Helm`)
6. Git for Windows at default path (`winget install Git.Git`)
7. make — see prerequisites doc for PATH setup

### Spin up the cluster

```powershell
make infra
make verify-infra
```

### Install platform primitives

```powershell
make platform
make verify-platform
```

Add to your Windows hosts file (`C:\Windows\System32\drivers\etc\hosts`):

```
192.168.56.200  stacklayer.local
```

### Install GitOps (Phase 3)

```powershell
make gitops
make verify-gitops
```

Add to your Windows hosts file:

```
192.168.56.200  argocd.stacklayer.local
```

ArgoCD UI is at https://argocd.stacklayer.local — credentials are printed by `make gitops`.
See [docs/argocd-connect-repo.md](docs/argocd-connect-repo.md) to connect your first repo.

### Install Observability (Phase 4)

```powershell
make observability
make verify-observability
```

Add to your Windows hosts file:

```
192.168.56.200  grafana.stacklayer.local
```

Grafana is at https://grafana.stacklayer.local — credentials: `admin` / `stacklayer`.

### Power the cluster on and off

```powershell
make stop   # graceful shutdown
make start  # power back on (workloads resume automatically)
```

After `make start`, wait ~60s for the API server, then verify:

```powershell
make verify-infra
make verify-platform
make verify-gitops
```

> **Do not run `make infra` to resume** — that re-provisions the VMs from scratch.

### Tear down

```powershell
make destroy
```

To rebuild from scratch:

```powershell
make infra
make verify-infra
```

## Repository Structure

```
stacklayer/
├── Makefile
├── docs/
│   ├── prerequisites.md                       # What to install on the host
│   ├── architecture.md                        # High-level overview, links to phase docs
│   ├── phase1-infrastructure-architecture.md  # Phase 1 design decisions
│   ├── phase2-platform-architecture.md        # Phase 2 design decisions
│   ├── phase3-gitops-architecture.md          # Phase 3 design decisions
│   └── argocd-connect-repo.md                 # How to connect a repo to ArgoCD
├── phase1-infrastructure/
│   ├── Vagrantfile             # VM definitions
│   └── scripts/
│       ├── common.sh           # All nodes: containerd, kubeadm, kubelet, kubectl
│       ├── master-init.sh      # Control plane: kubeadm init + Flannel CNI
│       ├── worker-join.sh      # Workers: join cluster via shared join command
│       └── verify.sh           # Smoke test: nodes Ready, test pod
├── phase2-platform/
│   ├── helm-values/
│   │   ├── metallb-values.yaml
│   │   ├── ingress-nginx-values.yaml
│   │   └── cert-manager-values.yaml
│   ├── manifests/
│   │   ├── metallb-ippool.yaml  # IPAddressPool + L2Advertisement
│   │   └── clusterissuer.yaml   # Self-signed ClusterIssuer
│   └── scripts/
│       ├── install.sh           # Installs all Phase 2 components in order
│       └── verify.sh            # Smoke tests all Phase 2 components
└── phase3-gitops/
    ├── helm-values/
    │   └── argocd-values.yaml
    ├── manifests/
    │   └── argocd-ingress.yaml  # Ingress for argocd.stacklayer.local
    └── scripts/
        ├── install.sh           # Installs ArgoCD
        └── verify.sh            # Smoke tests ArgoCD
```

## Networking

| CIDR              | Purpose                    |
|-------------------|----------------------------|
| 192.168.56.0/24   | VM host-only network       |
| 192.168.56.200–220| MetalLB LoadBalancer pool  |
| 10.244.0.0/16     | Pod network (Flannel)      |
| 10.96.0.0/12      | Service network            |

## Design Principles

- **Reproducible** — `vagrant destroy && vagrant up` returns you to a clean cluster
- **Layered** — each phase is designed and documented before the next begins
- **Shareable** — the only host requirement is Windows 11 + VMware Workstation Pro
