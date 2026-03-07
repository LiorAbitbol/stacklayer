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
| 4     | Observability       | Planned   | —                                            |
| 5     | Developer Platform  | Planned   | —                                            |

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

## Design Principles

- **Reproducible** — `vagrant destroy && vagrant up` returns to a clean cluster
- **Layered** — each phase is designed and documented before the next begins
- **Deliberate** — no speculative tooling; decisions are made with rationale
- **Shareable** — the only host requirement is Windows 11 + VMware Workstation Pro
