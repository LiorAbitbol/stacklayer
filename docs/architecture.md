# Architecture — StackLayer

StackLayer is built phase by phase. Each phase has its own architecture document with
detailed design decisions. This document provides a high-level overview of the whole system
as it grows.

## Phase Map

| Phase | Name                | Status    | Doc                                          |
|-------|---------------------|-----------|----------------------------------------------|
| 1     | Infrastructure      | Complete  | [phase1-infrastructure-architecture.md](phase1-infrastructure-architecture.md) |
| 2     | Platform Primitives | Complete  | [phase2-platform-architecture.md](phase2-platform-architecture.md) |
| 3     | GitOps              | Complete  | [phase3-gitops-architecture.md](phase3-gitops-architecture.md) |
| 4     | Observability       | Complete  | [phase4-observability-architecture.md](phase4-observability-architecture.md) |

## System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│  Windows 11 Host                                                 │
│                                                                  │
│  kubectl / helm / make                                           │
│  hosts: 192.168.56.200  stacklayer.local                        │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Kubernetes Cluster (Phase 1)                              │  │
│  │                                                            │  │
│  │  k8s-controller-1  192.168.56.10  control-plane           │  │
│  │  k8s-worker-1      192.168.56.11  worker                  │  │
│  │  k8s-worker-2      192.168.56.12  worker                  │  │
│  │                                                            │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │  Platform Layer (Phase 2)                           │  │  │
│  │  │                                                     │  │  │
│  │  │  MetalLB        → LoadBalancer IPs (56.200–220)     │  │  │
│  │  │  ingress-nginx  → 192.168.56.200 (pinned)           │  │  │
│  │  │  cert-manager   → self-signed TLS                   │  │  │
│  │  │  local-path     → default StorageClass              │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## Network Summary

| Network         | CIDR              | Purpose                        |
|-----------------|-------------------|--------------------------------|
| VM host-only    | 192.168.56.0/24   | VM-to-VM + host-to-cluster     |
| MetalLB pool    | 192.168.56.200–220| LoadBalancer IP range          |
| Pod network     | 10.244.0.0/16     | Flannel inter-pod routing      |
| Service network | 10.96.0.0/12      | Kubernetes ClusterIP range     |

## Tutorials

Step-by-step guides for deploying applications to the cluster:

- [tutorials/README.md](tutorials/README.md) — index
- [tutorials/01-fastapi-sample-app.md](tutorials/01-fastapi-sample-app.md) — FastAPI app with Kubernetes manifests
- [tutorials/02-argocd-deploy.md](tutorials/02-argocd-deploy.md) — Deploy with ArgoCD
- [tutorials/03-app-observability.md](tutorials/03-app-observability.md) — Wire an app into Prometheus and Grafana

## Component Versions

All Helm chart versions and manifest URLs are pinned in each phase's `install.sh` for reproducibility.
To find a newer version before upgrading, each install script includes a comment with the lookup command.

| Phase | Component               | Version        |
|-------|-------------------------|----------------|
| 2     | MetalLB                 | 0.14.9         |
| 2     | ingress-nginx           | 4.12.1         |
| 2     | cert-manager            | 1.17.2         |
| 2     | local-path-provisioner  | 0.0.31         |
| 3     | ArgoCD (argo-cd)        | 7.8.23         |
| 4     | kube-prometheus-stack   | 70.4.2         |

To upgrade a component: update the `--version` flag in the relevant `install.sh`, then re-run the
corresponding `make` target (`helm upgrade --install` is idempotent).

## Tool Credentials

All StackLayer tools use the same credentials for simplicity:

| Tool       | URL                              | Username | Password    |
|------------|----------------------------------|----------|-------------|
| ArgoCD     | https://argocd.stacklayer.local  | admin    | stacklayer  |
| Grafana    | https://grafana.stacklayer.local | admin    | stacklayer  |

## Design Principles

- **Reproducible** — `vagrant destroy && vagrant up` returns to a clean cluster
- **Layered** — each phase is designed and documented before the next begins
- **Deliberate** — no speculative tooling; decisions are made with rationale
- **Shareable** — the only host requirement is Windows 11 + VMware Workstation Pro
