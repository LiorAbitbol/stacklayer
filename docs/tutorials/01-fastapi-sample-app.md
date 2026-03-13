# Tutorial 1 — FastAPI Sample App

Create a GitHub repository with a minimal FastAPI application, a Dockerfile, and the
Kubernetes manifests needed to deploy it to the StackLayer cluster.

By the end of this guide you will have:
- A GitHub repo with a working FastAPI app
- A Docker image pushed to GitHub Container Registry (ghcr.io)
- Kubernetes manifests that deploy the app at `https://hello.stacklayer.local`

---

## Step 1 — Create the GitHub repository

1. Go to https://github.com/new
2. Name it `hello-stacklayer`
3. Set it to **Public** (ArgoCD can pull public repos without credentials)
4. Do not add a README — you'll push everything from your machine
5. Click **Create repository**

Clone it locally:

```powershell
git clone https://github.com/<your-username>/hello-stacklayer
cd hello-stacklayer
```

---

## Step 2 — Write the application

**`main.py`**

```python
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def root():
    return {"message": "Hello from StackLayer!"}


@app.get("/health")
def health():
    return {"status": "ok"}
```

**`requirements.txt`**

```
fastapi==0.115.0
uvicorn[standard]==0.30.0
```

---

## Step 3 — Write the Dockerfile

**`Dockerfile`**

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Test it locally before going further:

```powershell
docker build -t hello-stacklayer .
docker run --rm -p 8000:8000 hello-stacklayer
# Open http://localhost:8000 — should return {"message": "Hello from StackLayer!"}
```

---

## Step 4 — Push the image to GitHub Container Registry

The StackLayer cluster has no local image registry. GitHub Container Registry (ghcr.io)
keeps your image in the same place as your code — no separate account needed.

### Create a Personal Access Token

ghcr.io requires a PAT to push images (your GitHub password won't work).

1. Go to https://github.com/settings/tokens
2. Click **Generate new token (classic)**
3. Give it a name (e.g. `ghcr-push`), set an expiry, and tick the **`write:packages`** scope
4. Click **Generate token** and copy it — you will not see it again

### Log in and push

```powershell
docker login ghcr.io -u <your-github-username> -p <your-pat>

docker tag hello-stacklayer ghcr.io/<your-github-username>/hello-stacklayer:latest
docker push ghcr.io/<your-github-username>/hello-stacklayer:latest
```

### Make the package public

Packages pushed to ghcr.io are **private by default**. The cluster needs to pull the
image without credentials, so make it public:

1. Go to https://github.com/<your-username>?tab=packages
2. Click `hello-stacklayer`
3. Go to **Package settings** (bottom right)
4. Under **Danger Zone**, click **Change visibility → Public**

> For subsequent changes, build and push a new tag (e.g. `:v2`) and update the image
> reference in `k8s/deployment.yaml`. Using `latest` is fine for a local lab.

---

## Step 5 — Write the Kubernetes manifests

Create a `k8s/` directory in the repo root. ArgoCD will watch this directory.

```powershell
mkdir k8s
```

**`k8s/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-stacklayer
  namespace: hello-stacklayer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-stacklayer
  template:
    metadata:
      labels:
        app: hello-stacklayer
    spec:
      containers:
        - name: hello-stacklayer
          image: ghcr.io/<your-github-username>/hello-stacklayer:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8000
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 5
            periodSeconds: 10
```

**`k8s/service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-stacklayer
  namespace: hello-stacklayer
spec:
  selector:
    app: hello-stacklayer
  ports:
    - port: 80
      targetPort: 8000
```

**`k8s/ingress.yaml`**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-stacklayer
  namespace: hello-stacklayer
  annotations:
    cert-manager.io/cluster-issuer: selfsigned
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - hello.stacklayer.local
      secretName: hello-stacklayer-tls
  rules:
    - host: hello.stacklayer.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-stacklayer
                port:
                  number: 80
```

> The `cert-manager.io/cluster-issuer: selfsigned` annotation tells cert-manager to
> issue a self-signed TLS certificate for this ingress. Your browser will show a
> certificate warning — expected for a local lab.

---

## Step 6 — Commit and push

Your repo should look like this:

```
hello-stacklayer/
├── Dockerfile
├── main.py
├── requirements.txt
└── k8s/
    ├── deployment.yaml
    ├── service.yaml
    └── ingress.yaml
```

```powershell
git add .
git commit -m "Initial FastAPI app with Kubernetes manifests"
git push origin main
```

---

## Next step

Continue to [Tutorial 2 — Deploy with ArgoCD](02-argocd-deploy.md) to connect this repo
to ArgoCD and deploy the app to the cluster.
