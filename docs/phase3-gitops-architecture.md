# Architecture — Phase 3: GitOps

## Overview

Phase 3 installs ArgoCD — the GitOps controller for the cluster. From this point on,
application deployments are driven by Git rather than manual `kubectl apply` or `helm install`
commands. ArgoCD watches GitHub repositories and reconciles the cluster state to match.

## Components

| Component | Version | Purpose                              |
|-----------|---------|--------------------------------------|
| ArgoCD    | 7.8.23  | GitOps controller with web UI        |

## Access

| Endpoint                          | Details                              |
|-----------------------------------|--------------------------------------|
| https://argocd.stacklayer.local   | Web UI (self-signed TLS)             |
| Username                          | admin                                |
| Password                          | Printed by `make gitops` and `make verify-gitops` |

Add to your Windows hosts file (`C:\Windows\System32\drivers\etc\hosts`):
```
192.168.56.200  argocd.stacklayer.local
```

## Architecture

```
Browser → argocd.stacklayer.local
               ↓
       192.168.56.200 (ingress-nginx, MetalLB)
               ↓
       Ingress: argocd-server (TLS terminated here)
               ↓
       argocd-server Service (HTTP/80)
               ↓
       ArgoCD server pod (insecure mode)
               ↓
       Watches GitHub repos → syncs to cluster
```

## TLS

ArgoCD runs in **insecure mode** (`server.insecure: true`) — it serves plain HTTP internally.
TLS is terminated at ingress-nginx, with a certificate issued by cert-manager using the
`selfsigned` ClusterIssuer. Browsers will show a certificate warning — expected for a local lab.

This is simpler than SSL passthrough and consistent with how all other services in the lab
will expose HTTPS.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| GitOps tool | ArgoCD | Rich web UI, widely adopted, well-documented; Flux would work equally well but has no UI |
| ArgoCD TLS mode | Insecure (HTTP internally, HTTPS at ingress) | Consistent with all other services; avoids SSL passthrough complexity |
| Git host | GitHub | Already in use; no operational overhead vs self-hosted Gitea |
| App bootstrap | Manual (no pre-configured Applications) | ArgoCD is infrastructure — what it watches is determined per-project, not here |
| Ingress | Separate manifest (not via Helm values) | Keeps the Helm values clean; ingress config lives alongside other manifests |

## What ArgoCD Does NOT Manage (by design)

Phase 1 and Phase 2 components (Vagrant, kubeadm, MetalLB, ingress-nginx, cert-manager,
local-path-provisioner) are **not** managed by ArgoCD. They were installed before ArgoCD
existed and are considered cluster infrastructure, not application workloads.

ArgoCD manages application repositories that you connect to it manually. See
[argocd-connect-repo.md](argocd-connect-repo.md) for how to do this.

## What This Phase Does Not Include

Deliberately left for future phases:

- Observability (Phase 4 — Prometheus/Grafana/Loki)
- Developer platform (Phase 5 — Backstage)
