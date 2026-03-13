# Tutorial 3 — App Observability with Prometheus and Grafana

Wire the `hello-stacklayer` app into the cluster's observability stack so Prometheus
scrapes its metrics and you can query and visualize them in Grafana.

This picks up from [Tutorial 2](02-argocd-deploy.md). By the end you will have:
- A `/metrics` endpoint on the FastAPI app emitting Prometheus-format metrics
- A `ServiceMonitor` telling Prometheus to scrape it
- Requests, latency, and error rate visible in Grafana

**Prerequisite:** Phase 4 must be installed (`make observability && make verify-observability`).

---

## How Prometheus discovers app metrics

Prometheus does not scrape every service automatically. You opt in by creating a
`ServiceMonitor` — a custom resource that tells Prometheus which service to scrape, on
which port, and at what path. kube-prometheus-stack watches for `ServiceMonitor` resources
across all namespaces and adds them to Prometheus's scrape configuration automatically.

---

## Step 1 — Add metrics to the app

Install `prometheus-fastapi-instrumentator`, which adds a `/metrics` endpoint to any
FastAPI app with a single call.

**`requirements.txt`** — add the new dependency:

```
fastapi==0.115.0
uvicorn[standard]==0.30.0
prometheus-fastapi-instrumentator==7.0.0
```

**`main.py`** — instrument the app on startup:

```python
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()

Instrumentator().instrument(app).expose(app)


@app.get("/")
def root():
    return {"message": "Hello from StackLayer!"}


@app.get("/health")
def health():
    return {"status": "ok"}
```

The `.expose(app)` call adds the `/metrics` route. Test it locally:

```powershell
docker build -t hello-stacklayer .
docker run --rm -p 8000:8000 hello-stacklayer
curl http://localhost:8000/metrics
# Should return Prometheus-format text with http_requests_total, http_request_duration_seconds, etc.
```

---

## Step 2 — Update the Service

`ServiceMonitor` references ports by **name**, not by number, and its `selector` matches
labels on the **Service object itself**. Update `k8s/service.yaml` to add both:

**`k8s/service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-stacklayer
  namespace: hello-stacklayer
  labels:
    app: hello-stacklayer
spec:
  selector:
    app: hello-stacklayer
  ports:
    - name: http
      port: 80
      targetPort: 8000
```

---

## Step 3 — Add the ServiceMonitor

Create `k8s/servicemonitor.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: hello-stacklayer
  namespace: hello-stacklayer
spec:
  selector:
    matchLabels:
      app: hello-stacklayer
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

| Field | Value | Notes |
|---|---|---|
| `selector.matchLabels` | `app: hello-stacklayer` | Must match the labels on the Service |
| `port` | `http` | The named port from `service.yaml` |
| `path` | `/metrics` | Where the app exposes metrics |
| `interval` | `30s` | How often Prometheus scrapes |

---

## Step 4 — Push the updated image

```powershell
docker build -t ghcr.io/<your-github-username>/hello-stacklayer:latest .
docker push ghcr.io/<your-github-username>/hello-stacklayer:latest
```

---

## Step 5 — Commit and push

Your repo should now look like:

```
hello-stacklayer/
├── Dockerfile
├── main.py
├── requirements.txt
└── k8s/
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── servicemonitor.yaml
```

```powershell
git add .
git commit -m "Add Prometheus metrics and ServiceMonitor"
git push origin main
```

ArgoCD will detect the commit and sync within a few minutes. You can trigger an immediate
sync from the ArgoCD UI: **Applications → hello-stacklayer → Sync → Synchronize**.

Verify the ServiceMonitor was applied:

```powershell
kubectl get servicemonitor -n hello-stacklayer
```

---

## Step 6 — Generate traffic

Prometheus needs something to scrape. Send a few requests to the app:

```powershell
for ($i = 0; $i -lt 20; $i++) {
  curl.exe https://hello.stacklayer.local/ -k -s | Out-Null
  curl.exe https://hello.stacklayer.local/health -k -s | Out-Null
}
```

---

## Step 7 — Verify in Prometheus

Prometheus has a built-in UI you can reach via port-forward:

```powershell
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Open **http://localhost:9090** in your browser.

**Check the scrape target is registered:**

1. Go to **Status → Target health**
2. Search for `hello-stacklayer` — you should see it with state **UP**

**Run a query:**

In the **Graph** tab, enter:

```
rate(http_requests_total{job="hello-stacklayer"}[5m])
```

Click **Execute**. You should see per-route request rates.

---

## Step 8 — Explore in Grafana

Open **https://grafana.stacklayer.local** and log in (`admin` / `stacklayer`).

### Query metrics in Explore

1. Click the **Explore** icon (compass) in the left sidebar
2. Select **Prometheus** as the data source
3. Enter a PromQL query and click **Run query**

Useful queries for the hello-stacklayer app:

| What | PromQL |
|---|---|
| Request rate (req/s) | `rate(http_requests_total{job="hello-stacklayer"}[5m])` |
| P95 latency | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="hello-stacklayer"}[5m]))` |
| Error rate (5xx) | `rate(http_requests_total{job="hello-stacklayer", status=~"5.."}[5m])` |
| Total requests | `sum(http_requests_total{job="hello-stacklayer"}) by (handler, status)` |

### Create a dashboard panel

1. Click **Dashboards → New → New dashboard**
2. Click **Add visualization**
3. Select **Prometheus** as the data source
4. Enter the request rate query: `rate(http_requests_total{job="hello-stacklayer"}[5m])`
5. Set the panel title to **Request Rate**
6. Click **Apply**, then **Save dashboard**

---

## What you've learned

- The `ServiceMonitor` pattern for opting any service into Prometheus scraping
- How Prometheus discovers scrape targets via `ServiceMonitor` resources
- Basic PromQL for rate, latency percentiles, and error rates
- How to use Grafana Explore and build dashboard panels

This same pattern applies to any app deployed on the cluster — add a `/metrics` endpoint
and a `ServiceMonitor`, and it appears in Prometheus automatically.
