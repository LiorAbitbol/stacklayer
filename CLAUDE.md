# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make infra           # Provision VMs + bootstrap Kubernetes + copy kubeconfig (~15 min)
make verify-infra    # Smoke test cluster health
make platform        # Install MetalLB, ingress-nginx, cert-manager, local-path-provisioner
make verify-platform # Smoke test platform health
make gitops          # Install ArgoCD
make verify-gitops   # Smoke test ArgoCD
make kubeconfig      # Re-copy kubeconfig from controller (without reprovisioning)
make destroy         # Destroy all VMs (prompts for confirmation)
```

To power cluster on/off without destroying it:
```bash
make stop    # graceful shutdown
make start   # power back on (workloads resume automatically)
```

After `make start`, wait ~60s for the API server, then verify:
```bash
make verify-infra
make verify-platform
make verify-gitops
```

**Do not run `make infra` to resume** — that re-provisions the VMs from scratch.

To relocate VM storage off the project drive:
```powershell
$env:STACKLAYER_VM_DIR = "D:\VMs\stacklayer"
make infra
```

## Architecture

StackLayer is a phased Kubernetes lab built on Windows 11 + VMware Workstation Pro. Each phase is designed and fully documented before the next begins.

### Phase structure

Each phase directory follows the same layout:
```
phaseN-*/
  helm-values/   # Helm override values passed to helm upgrade --install
  manifests/     # Raw kubectl apply manifests
  scripts/
    install.sh   # Invoked by make <phase-target>
    verify.sh    # Invoked by make verify-<phase>
```

Install scripts always run from repo root via `make`, which sets `SHELL` to Git Bash (`C:/Program Files/Git/usr/bin/bash.exe`). Scripts export `PATH="/usr/bin:/bin:$PATH"` at the top because GnuWin32 make doesn't pass the Git PATH through.

### Phase 1 — Infrastructure

Three Ubuntu 22.04 VMs provisioned by Vagrant + `vagrant-vmware-desktop`:

| Node | IP | Role |
|---|---|---|
| k8s-controller-1 | 192.168.56.10 | control-plane |
| k8s-worker-1 | 192.168.56.11 | worker |
| k8s-worker-2 | 192.168.56.12 | worker |

Bootstrap order: `common.sh` on all nodes → `master-init.sh` on controller (writes `join-command.sh` to the Vagrant synced folder) → `worker-join.sh` on workers (reads from synced folder). Kubernetes version is controlled by `KUBERNETES_VERSION` in the Vagrantfile. CNI is Flannel (pod CIDR 10.244.0.0/16).

### Phase 2 — Platform

Installed in order by `phase2-platform/scripts/install.sh`:
1. **MetalLB** (L2 mode) — pool 192.168.56.200–220
2. **ingress-nginx** — gets 192.168.56.200 (first allocation, effectively pinned)
3. **cert-manager** — self-signed `ClusterIssuer` via `manifests/clusterissuer.yaml`
4. **local-path-provisioner** — set as default `StorageClass`

Domain `stacklayer.local` is added to the Windows hosts file (not nip.io).

### Phase 3 — GitOps

ArgoCD installed via Helm (chart version pinned in `install.sh`). Exposed at `https://argocd.stacklayer.local` through the ingress-nginx LoadBalancer. Initial admin password printed by `make gitops`. See [docs/argocd-connect-repo.md](docs/argocd-connect-repo.md) for connecting a repo.

## Documentation

Phase architecture decisions live in `docs/phase{N}-*-architecture.md`. Read these before modifying a phase — they capture the rationale behind tooling and configuration choices.

## Working conventions

- **One phase at a time** — design and document each phase fully before scaffolding the next.
- **No speculative tooling** — only add components that serve the current phase.
- Git branches follow the pattern `phase{N}-{name}` and merge to `main` via PR when the phase is complete.
