# How to Connect a GitHub Repo to ArgoCD

This guide walks through connecting a GitHub repository to ArgoCD and deploying
your first application from it.

## Prerequisites

- Phase 3 installed and verified (`make gitops && make verify-gitops`)
- A GitHub repository containing Kubernetes manifests or a Helm chart
- ArgoCD UI accessible at https://argocd.stacklayer.local

## Step 1 — Log in to ArgoCD

Get the initial admin password:

```powershell
kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath='{.data.password}' | `
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
```

Open https://argocd.stacklayer.local in your browser, log in with:
- **Username:** admin
- **Password:** (output from above)

> **Tip:** Change the admin password after first login via **User Info → Update Password**.

## Step 2 — Connect the GitHub repository

### Option A — Via the UI

1. Go to **Settings → Repositories → Connect Repo**
2. Choose connection method: **HTTPS**
3. Fill in:
   - **Repository URL:** `https://github.com/your-org/your-repo`
   - **Username:** your GitHub username (for private repos)
   - **Password:** a GitHub Personal Access Token with `repo` scope (for private repos)
4. Click **Connect**

For public repos, leave username and password blank.

### Option B — Via kubectl

Create a repository secret directly:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/your-org/your-repo
  # Remove username/password for public repos
  username: your-github-username
  password: ghp_yourpersonalaccesstoken
```

```powershell
kubectl apply -f repo-secret.yaml
```

## Step 3 — Create an Application

An ArgoCD `Application` tells ArgoCD what to deploy and where.

### Option A — Via the UI

1. Go to **Applications → New App**
2. Fill in:
   - **Application Name:** `my-app`
   - **Project:** `default`
   - **Sync Policy:** Manual (or Automatic)
   - **Repository URL:** select the repo you connected
   - **Revision:** `HEAD` (or a branch/tag)
   - **Path:** the folder in the repo containing your manifests (e.g. `manifests/` or `.`)
   - **Cluster URL:** `https://kubernetes.default.svc`
   - **Namespace:** the target namespace (e.g. `default`)
3. Click **Create**

### Option B — Via manifest

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

```powershell
kubectl apply -f app.yaml
```

## Step 4 — Sync the application

### Manual sync (default)

In the UI, click the application → **Sync → Synchronize**.

Or via CLI (if you install the `argocd` CLI):

```powershell
argocd app sync my-app
```

### Automatic sync

To have ArgoCD sync automatically on every Git push, set in the Application spec:

```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources removed from Git
    selfHeal: true   # Revert manual changes made directly to the cluster
```

## Step 5 — Verify

In the ArgoCD UI, the application should show:
- **Status:** Synced
- **Health:** Healthy

Or via kubectl:

```powershell
kubectl get application my-app -n argocd
```

## Ingress for your application

To expose your app via `stacklayer.local`, add an Ingress resource in your repo:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-app
  annotations:
    cert-manager.io/cluster-issuer: selfsigned
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - my-app.stacklayer.local
      secretName: my-app-tls
  rules:
    - host: my-app.stacklayer.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

Then add to your Windows hosts file:
```
192.168.56.200  my-app.stacklayer.local
```

## Notes

- The `argocd-initial-admin-secret` is deleted by ArgoCD after you change the password.
  Store the password somewhere safe before changing it.
- Each app repo is independent — you can connect as many repos as you like.
- ArgoCD does not manage Phase 1 or Phase 2 cluster infrastructure — only application
  repos you explicitly connect to it.
