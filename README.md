# StackLayer

A locally reproducible lab environment that mirrors production Kubernetes infrastructure.
Built phase by phase — each phase is fully documented before the next begins.

**Host:** Windows 11 + VMware Workstation Pro. Automated enough to tear down and rebuild
at will. Shareable with others who have similar setups.

## Documentation

- [docs/prerequisites.md](docs/prerequisites.md) — what to install on the host
- [docs/architecture.md](docs/architecture.md) — full architecture overview and phase map

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
make up
make kubeconfig
make verify
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

### Power the cluster on and off

```powershell
cd phase1-infrastructure
vagrant halt    # graceful shutdown
vagrant up      # power back on
```

### Tear down

```powershell
make destroy
```

To rebuild from scratch:

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
        ├── install.sh           # Installs all Phase 2 components in order
        └── verify.sh            # Smoke tests all Phase 2 components
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
