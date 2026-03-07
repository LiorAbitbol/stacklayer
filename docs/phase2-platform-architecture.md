# Architecture — Phase 2: Platform Primitives

## Overview

Phase 2 installs the foundational platform layer on top of the Phase 1 cluster. These
components are prerequisites for all application workloads in later phases.

## Components

| Component               | Version | Purpose                                      |
|-------------------------|---------|----------------------------------------------|
| MetalLB                 | 0.14.9  | LoadBalancer IPs for bare-metal cluster       |
| ingress-nginx           | 4.12.1  | HTTP/HTTPS ingress controller                |
| cert-manager            | 1.17.2  | TLS certificate management                   |
| local-path-provisioner  | 0.0.31  | Default StorageClass for PersistentVolumes   |

## Networking

```
┌──────────────────────────────────────────────────────────────┐
│  Windows 11 Host                                             │
│                                                              │
│  hosts file: 192.168.56.200  stacklayer.local                │
│                                                              │
│  Browser → stacklayer.local → 192.168.56.200                 │
│                ↓                                             │
│  ┌─────────────────────────────────────────────────────┐     │
│  │  Kubernetes Cluster (192.168.56.0/24)               │     │
│  │                                                     │     │
│  │  MetalLB pool: 192.168.56.200–192.168.56.220        │     │
│  │                                                     │     │
│  │  ingress-nginx  ←→  192.168.56.200 (pinned)         │     │
│  │       ↓                                             │     │
│  │  Ingress rules → Services → Pods                    │     │
│  └─────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
```

## IP Allocation

| IP              | Assignment                  |
|-----------------|-----------------------------|
| 192.168.56.200  | ingress-nginx (pinned)      |
| 192.168.56.201–220 | Reserved for future use  |

## DNS Strategy

DNS is handled via the Windows hosts file at
`C:\Windows\System32\drivers\etc\hosts`. No external DNS server is required.

Entry to add:
```
192.168.56.200  stacklayer.local
```

Future services will use subdomains of `stacklayer.local`:
- `argocd.stacklayer.local`
- `grafana.stacklayer.local`
- etc.

## TLS Strategy

cert-manager is configured with a `selfsigned` ClusterIssuer. Ingress resources
annotated with `cert-manager.io/cluster-issuer: selfsigned` get self-signed certificates.
Browsers will show a certificate warning — expected for a local lab.

## Storage Strategy

`local-path-provisioner` provides a default StorageClass backed by node-local disk.
Volumes are created under `/opt/local-path-provisioner` on whichever node the pod
is scheduled. This is sufficient for single-replica workloads in a lab environment.

No distributed storage (Ceph, MinIO, Longhorn) is included in this phase — that
complexity is not justified until workloads that need it exist.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| LoadBalancer implementation | MetalLB L2 mode | No BGP router available; L2 ARP announcements work on a flat LAN — exactly what the host-only VMware network is |
| Ingress controller | ingress-nginx | Widely used, well-documented, straightforward config; no service mesh needed at this stage |
| Certificate management | cert-manager (self-signed) | Production-grade tooling with trivial config; self-signed acceptable for local lab |
| Storage | local-path-provisioner | Zero-dependency, zero-config; sufficient for lab workloads that need PVCs |
| DNS | Windows hosts file | No infrastructure to maintain; direct, reproducible, shareable |
| Installation method | Helm + shell script | Helm manages chart versions and values explicitly; shell script is readable and auditable |
| Domain | stacklayer.local | Clear, memorable, scoped to this lab |

## Key Tradeoffs Noted

- **MetalLB L2 vs BGP**: L2 is simpler — no router configuration — but does not scale
  and has failover limitations. Acceptable for a single-host lab. BGP mode would be used
  in a real bare-metal environment with a BGP-capable router.

- **self-signed vs Let's Encrypt**: Let's Encrypt requires a public domain and internet
  access to the cluster. Self-signed is the only practical option for a local lab.
  cert-manager supports switching issuers per-Ingress, so ACME can be added later for
  any public-facing variant.

- **local-path vs Longhorn**: Longhorn provides distributed storage with replication but
  requires significant resources and operational overhead. local-path is sufficient for
  phase-by-phase lab use where data persistence is not a primary concern.

## Installation Order

The install script applies components in dependency order:

1. MetalLB (must exist before any LoadBalancer service)
2. MetalLB IPAddressPool + L2Advertisement (CRDs available after MetalLB is Running)
3. ingress-nginx (needs MetalLB to get a LoadBalancer IP)
4. cert-manager (independent, but needed before any Ingress with TLS)
5. cert-manager webhook ready → ClusterIssuer (webhook must be up before applying CRs)
6. local-path-provisioner (independent)

## What This Phase Does Not Include

Deliberately left for future phases:

- GitOps controller (Phase 3 — ArgoCD)
- Observability stack (Phase 4 — Prometheus/Grafana/Loki)
- Developer platform (Phase 5 — Backstage)
