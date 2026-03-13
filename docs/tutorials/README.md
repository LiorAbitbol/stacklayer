# Tutorials

Step-by-step guides for deploying applications to the StackLayer cluster using ArgoCD.

## Prerequisites

- Phases 1–3 installed and verified (required for all tutorials):
  ```powershell
  make infra && make verify-infra
  make platform && make verify-platform
  make gitops && make verify-gitops
  ```
- Phase 4 installed and verified (required for Tutorial 3):
  ```powershell
  make observability && make verify-observability
  ```
- A GitHub account (also used for the container image via ghcr.io)
- Docker Desktop (or Docker CLI) installed on your Windows host

## Guides

| # | Guide | What you'll do | Requires |
|---|-------|----------------|----------|
| 1 | [FastAPI Sample App](01-fastapi-sample-app.md) | Create a GitHub repo with a FastAPI app, Dockerfile, and Kubernetes manifests | Phases 1–2 |
| 2 | [Deploy with ArgoCD](02-argocd-deploy.md) | Connect the repo to ArgoCD and deploy the app to the cluster | Phase 3 |
| 3 | [App Observability](03-app-observability.md) | Wire the app into Prometheus and Grafana with a ServiceMonitor | Phase 4 |

Work through them in order — each guide picks up where the previous left off.
