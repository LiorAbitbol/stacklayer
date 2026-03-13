# Architecture — Phase 4: Observability

## Overview

Phase 4 installs `kube-prometheus-stack` — a single Helm chart that bundles Prometheus,
Grafana, Alertmanager, node-exporter, and kube-state-metrics. It provides cluster-wide
metrics collection and a Grafana UI for dashboards.

Phase 4 is optional and independent of Phase 3. It requires only Phase 1 and Phase 2.

## Components

| Component          | Chart / Version                  | Purpose                                             |
|--------------------|----------------------------------|-----------------------------------------------------|
| Prometheus         | kube-prometheus-stack 70.4.2     | Metrics collection and storage                      |
| Grafana            | (bundled in chart)               | Dashboard UI                                        |
| Alertmanager       | (bundled in chart)               | Alert routing (ephemeral — no persistence in lab)   |
| node-exporter      | (bundled in chart)               | Per-node CPU, memory, disk, network metrics         |
| kube-state-metrics | (bundled in chart)               | Kubernetes object state metrics (pods, deployments) |

## Access

| Endpoint                           | Details                          |
|------------------------------------|----------------------------------|
| https://grafana.stacklayer.local   | Grafana UI (self-signed TLS)     |
| Username                           | admin                            |
| Password                           | Printed by `make observability`  |

Add to your Windows hosts file (`C:\Windows\System32\drivers\etc\hosts`):
```
192.168.56.200  grafana.stacklayer.local
```

## Architecture

```
Browser → grafana.stacklayer.local
               ↓
       192.168.56.200 (ingress-nginx, MetalLB)
               ↓
       Ingress: grafana (TLS terminated here)
               ↓
       Grafana Service → Grafana pod
               ↓
       Queries Prometheus (in-cluster, ClusterIP)
               ↑
       Prometheus scrapes:
         - node-exporter (DaemonSet, every node)
         - kube-state-metrics
         - kubelet / kube-apiserver / kube-scheduler
         - Alertmanager
```

## Storage

Metrics and dashboard configuration persist across pod restarts and cluster reboots via
PersistentVolumeClaims backed by `local-path-provisioner` (installed in Phase 2).

| Component   | PVC size | Retention  | Storage class |
|-------------|----------|------------|---------------|
| Prometheus  | 10Gi     | 7 days     | local-path    |
| Grafana     | 2Gi      | —          | local-path    |
| Alertmanager| none     | ephemeral  | —             |

Note: `local-path` volumes are node-local. If a node is destroyed and reprovisioned, its
volume data is lost. This is acceptable for a lab — reprovisioning the cluster is a clean-slate
operation anyway.

## TLS

Same pattern as Phase 3: Grafana serves plain HTTP internally, TLS terminated at ingress-nginx
with a cert-manager self-signed certificate. Browsers will show a certificate warning — expected.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Chart | kube-prometheus-stack | Bundles all components with pre-wired Prometheus datasource and default dashboards |
| Grafana ingress | Separate manifest | Consistent with Phase 3 (ArgoCD ingress); keeps Helm values focused on configuration |
| Storage | Persistent (local-path) | Metrics survive pod restarts with minimal added complexity; local-path is already available |
| Alertmanager | Ephemeral | Lab has no alerting targets; persisting alert state adds no value |
| Loki | Not included | Logs are a separate concern — can be added as an independent phase without dependencies here |

## What This Phase Does Not Include

Deliberately left for future phases:

- Log aggregation (Loki + Promtail)
- Developer platform (Phase 5 — Backstage)
