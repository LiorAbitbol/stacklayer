# Tutorial 2 — Deploy with ArgoCD

Connect the `hello-stacklayer` GitHub repo to ArgoCD and deploy the app to the cluster.

This picks up from [Tutorial 1](01-fastapi-sample-app.md). By the end you will have the
app running at `https://hello.stacklayer.local`, with ArgoCD keeping the cluster in sync
with the GitHub repo automatically.

---

## Step 1 — Log in to ArgoCD

Open **https://argocd.stacklayer.local** in your browser and log in:
- **Username:** `admin`
- **Password:** `stacklayer`

> Your browser will show a certificate warning because the TLS certificate is self-signed.
> Proceed past it.

---

## Step 2 — Connect the repository

If your repo is **public**, ArgoCD can pull it without credentials — skip to Step 3.

If your repo is **private**, add credentials first.

### Connect a private repo

Create a GitHub Personal Access Token (PAT):
1. Go to https://github.com/settings/tokens
2. Generate a **classic** token with the `repo` scope
3. Copy the token — you will not see it again

Create a repository secret in ArgoCD:

**`argocd-repo-secret.yaml`** (create this on your local machine, do not commit it)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hello-stacklayer-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/<your-username>/hello-stacklayer
  username: <your-github-username>
  password: <your-github-pat>
```

Apply it:

```powershell
kubectl apply -f argocd-repo-secret.yaml
```

Then delete the local file — it contains a secret:

```powershell
Remove-Item argocd-repo-secret.yaml
```

---

## Step 3 — Create the ArgoCD Application

An ArgoCD `Application` tells ArgoCD which repo to watch, which path in the repo contains
manifests, and which cluster and namespace to deploy to.

Create this file anywhere on your local machine (you do not need to commit it to the app
repo — ArgoCD stores the Application object in the cluster):

**`argocd-app.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-stacklayer
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<your-username>/hello-stacklayer
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: hello-stacklayer
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

| Field | Value | Notes |
|-------|-------|-------|
| `repoURL` | your GitHub repo | Replace `<your-username>` |
| `targetRevision` | `HEAD` | Tracks the default branch |
| `path` | `k8s` | The directory containing your manifests |
| `namespace` | `hello-stacklayer` | ArgoCD creates this namespace automatically |
| `automated.prune` | `true` | Deletes cluster resources removed from Git |
| `automated.selfHeal` | `true` | Reverts manual changes made directly to the cluster |
| `CreateNamespace` | `true` | ArgoCD creates the namespace if it does not exist |

Apply it:

```powershell
kubectl apply -f argocd-app.yaml
```

---

## Step 4 — Watch the sync

ArgoCD will detect the new Application and begin syncing within a few seconds.

Watch it in the **ArgoCD UI**:
1. Open https://argocd.stacklayer.local
2. The `hello-stacklayer` app will appear on the Applications page
3. Wait for **Status: Synced** and **Health: Healthy**

Or watch from the terminal:

```powershell
kubectl get application hello-stacklayer -n argocd -w
```

You should see `Sync Status` move to `Synced` and `Health Status` to `Healthy`.

To check the pods directly:

```powershell
kubectl get pods -n hello-stacklayer
```

Expected output:

```
NAME                                READY   STATUS    RESTARTS   AGE
hello-stacklayer-<hash>             1/1     Running   0          30s
```

---

## Step 5 — Add the hosts entry

Add the app's hostname to your Windows hosts file so the browser can resolve it.

Open Notepad **as Administrator** and edit:
`C:\Windows\System32\drivers\etc\hosts`

Add:

```
192.168.56.200  hello.stacklayer.local
```

---

## Step 6 — Verify

Open **https://hello.stacklayer.local** in your browser.

Accept the self-signed certificate warning. You should see:

```json
{"message": "Hello from StackLayer!"}
```

Check the health endpoint:

```powershell
curl.exe https://hello.stacklayer.local/health -k
# {"status":"ok"}
```

---

## How the GitOps loop works

Once the Application is created, the loop is:

```
You push a commit to GitHub
        ↓
ArgoCD detects the change (polls every 3 minutes by default)
        ↓
ArgoCD applies the updated manifests to the cluster
        ↓
Kubernetes reconciles — pods restart, resources update
```

To deploy a new version of the app:

```powershell
# Build and push new image
docker build -t <your-dockerhub-username>/hello-stacklayer:v2 .
docker push <your-dockerhub-username>/hello-stacklayer:v2

# Update k8s/deployment.yaml to reference :v2
# Commit and push
git add k8s/deployment.yaml
git commit -m "Deploy v2"
git push
```

ArgoCD will pick up the change and roll out the new version within a few minutes. You can
also trigger a sync immediately from the ArgoCD UI with **Sync → Synchronize**.

---

## Troubleshooting

**App stuck in `OutOfSync` or `Degraded`**

```powershell
kubectl describe application hello-stacklayer -n argocd
kubectl get events -n hello-stacklayer --sort-by='.lastTimestamp'
```

**Pods not starting — ImagePullBackOff**

The cluster cannot pull your image. Check two things:
1. The image name in `k8s/deployment.yaml` matches exactly what you pushed (`ghcr.io/<your-github-username>/hello-stacklayer:latest`)
2. The package visibility is set to **Public** on GitHub (see Step 4 of Tutorial 1)

**TLS certificate not Ready**

```powershell
kubectl get certificate -n hello-stacklayer
kubectl describe certificate hello-stacklayer-tls -n hello-stacklayer
```

cert-manager usually issues the certificate within 30 seconds of the Ingress being created.
If it is stuck, check cert-manager logs:

```powershell
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

**ArgoCD not detecting changes**

ArgoCD polls GitHub every 3 minutes. To trigger an immediate sync:
- UI: click the app → **Sync → Synchronize**
- CLI: `argocd app sync hello-stacklayer` (requires the `argocd` CLI)
