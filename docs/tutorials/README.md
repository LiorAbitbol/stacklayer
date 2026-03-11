# Tutorials

Step-by-step guides for deploying applications to the StackLayer cluster using ArgoCD.

## Prerequisites

- All three phases installed and verified:
  ```powershell
  make infra && make verify-infra
  make platform && make verify-platform
  make gitops && make verify-gitops
  ```
- A GitHub account (also used for the container image via ghcr.io)
- Docker Desktop (or Docker CLI) installed on your Windows host

## Guides

| # | Guide | What you'll do |
|---|-------|---------------|
| 1 | [FastAPI Sample App](01-fastapi-sample-app.md) | Create a GitHub repo with a FastAPI app, Dockerfile, and Kubernetes manifests |
| 2 | [Deploy with ArgoCD](02-argocd-deploy.md) | Connect the repo to ArgoCD and deploy the app to the cluster |

Work through them in order — guide 2 picks up where guide 1 leaves off.
