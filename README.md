# 🎬 LeoCinema - Kubernetes

🇧🇷 [Português](README.pt.md) | 🇺🇸 English

Full deployment of the **LeoCinema** application on Kubernetes, with support for Helm Chart, ArgoCD (GitOps), and NGINX Ingress Controller.

## 🏗️ Architecture

```
                        ┌─────────────────────┐
                        │   NGINX Ingress      │
                        │   (External IP)      │
                        └────────┬────────────┘
                                 │
               ┌─────────────────┴─────────────────┐
               │                                   │
        ┌──────▼──────┐                   ┌────────▼──────┐
        │  Frontend   │                   │    Backend    │
        │  (HTML/JS)  │ ───────────────►  │   (API REST)  │
        └─────────────┘                   └───────┬───────┘
                                                  │
                                         ┌────────▼──────┐
                                         │   MariaDB     │
                                         │  (Database)   │
                                         └───────────────┘
```

## 📁 Project Structure

```
app-leocinema-kubernetes/
├── environment/
│   ├── argocd.yaml       # ArgoCD Application (GitOps)
│   ├── cluster-env.sh    # Cluster setup script
│   └── get-ingress.yaml  # Helper to get the Ingress IP
├── helm/
│   └── leocinema/
│       ├── templates/    # Kubernetes templates
│       │   ├── backend.yaml
│       │   ├── frontend.yaml
│       │   ├── db.yaml
│       │   └── env.yaml
│       ├── Chart.yaml
│       ├── values.yaml        # Chart configuration (production profile)
│       └── values-local.yaml  # Local lab profile (Minikube)
├── monitoring/           # kube-prometheus-stack values + Grafana dashboard (v2)
└── manifests/            # Kubernetes manifests without Helm
    ├── manifest-backend.yaml
    ├── manifest-frontend.yaml
    ├── manifest-db.yaml
    └── manifest-env.yaml
```

## 🚀 Deploy

Choose one of the three paths below. They are independent of each other.

---

## 💻 Option 1 — Helm

### Local (Minikube)

```bash
# Install Minikube: https://minikube.sigs.k8s.io/docs/start/
minikube start
minikube addons enable ingress

# Wait for the NGINX controller to be ready before installing the chart
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s

# Start the tunnel (keep this terminal open)
minikube tunnel

# Deploy with the local lab profile: MariaDB inside the cluster, frontend enabled,
# Secret and ConfigMap created by Helm with demo credentials (see values-local.yaml)
helm install leocinema helm/leocinema/ \
  --namespace leocinema \
  --create-namespace \
  -f helm/leocinema/values-local.yaml

# Check it
kubectl get pods -n leocinema
curl http://127.0.0.1/api/health
```

> **Which profile?** The chart's default `values.yaml` is the **production profile** (database on RDS, Secret/ConfigMap managed by Terraform, frontend on S3 + CloudFront). Without those pieces the backend pods stay in `CreateContainerConfigError`. On a bare cluster always use `values-local.yaml`.

> **Windows with Docker driver:** the Minikube IP (`minikube ip`) is not directly accessible from Windows. Use `minikube tunnel` (`values-local.yaml` already sets `ingressIp` to `127.0.0.1`).

### Cloud (EKS, GKE, AKS...)

```bash
# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Get the external Ingress IP
kubectl apply -f environment/get-ingress.yaml
kubectl get ingresses  # wait for EXTERNAL-IP to appear
kubectl delete -f environment/get-ingress.yaml

# Label the nodes (optional)
kubectl label node <node-name> tier=app
kubectl label node <node-name> tier=db

# Deploy
# (add --set nodeSelectorEnabled=true if you labeled the nodes)
helm install leocinema helm/leocinema/ \
  --namespace leocinema \
  --create-namespace \
  -f helm/leocinema/values-local.yaml \
  --set ingressIp="<INGRESS-IP>"
```

---

## 🔄 Option 2 — ArgoCD (GitOps)

ArgoCD reads the Helm chart directly from the repository — no need to run Helm locally.

Before applying, edit `environment/argocd.yaml` with your environment values:

```yaml
helm:
  parameters:
    - name: ingressIp
      value: "127.0.0.1"    # 127.0.0.1 for Minikube tunnel on Windows, or cloud external IP
    - name: nodeSelectorEnabled
      value: "false"         # false for Minikube, true for cloud
```

```bash
# Create namespace and install ArgoCD
kubectl create namespace argocd
kubectl apply \
  --server-side \
  --force-conflicts \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get the admin password
# Linux/macOS:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# PowerShell:
[System.Text.Encoding]::UTF8.GetString(
    [System.Convert]::FromBase64String(
        (kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}")
    )
)

# Access the dashboard (http://localhost:8080)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Apply the ArgoCD Application
kubectl apply -f environment/argocd.yaml
```

ArgoCD will automatically sync with the repository and keep the cluster state aligned with the code.

> **Profiles:** the Application deploys the chart's default (production) profile, which expects the database, Secret and ConfigMap to come from Terraform. On a standalone cluster (Minikube, or a lab cluster without Terraform) add the local profile under `helm:` in `environment/argocd.yaml`:
>
> ```yaml
> helm:
>   valueFiles:
>     - values-local.yaml
>   parameters:
>     # ingressIp, nodeSelectorEnabled...
> ```
>
> - **Local (Minikube):** run `minikube tunnel` and keep `ingressIp` as `127.0.0.1`
> - **Cloud:** set `ingressIp` to the external Ingress IP and optionally label your nodes with `tier=app` / `tier=db`

---

## 📄 Option 3 — Manifests (without Helm)

```bash
# manifest-env.yaml ships with DEMO credentials (lab only) and the Ingress IP set to 127.0.0.1 (minikube tunnel).
# Cloud: edit the Ingress IP there. Local (Minikube): remove the nodeSelector from the backend, frontend and db manifests.
kubectl apply -f manifests/manifest-env.yaml
kubectl apply -f manifests/manifest-db.yaml
kubectl apply -f manifests/manifest-backend.yaml
kubectl apply -f manifests/manifest-frontend.yaml
```

---

## ⚙️ Configuration (`values.yaml`)

| Parameter | Description | Default |
|---|---|---|
| `managedByTerraform` | Secret/ConfigMap come from Terraform (production profile) | `true` |
| `createDb` | Runs MariaDB inside the cluster | `false` |
| `frontendEnabled` | Deploys the frontend in Kubernetes | `false` |
| `ingressEnabled` | Enables the external Ingress | `true` |
| `nodeSelectorEnabled` | Enables the nodeSelector | `false` |
| `ingressIp` | External Ingress IP | `""` |
| `theme` | Release theme (`red`/`green`/`blue`); prefixes the Ingress path | `""` |
| `metrics.serviceMonitor.enabled` | Creates the Prometheus ServiceMonitor | `false` |
| `db.minReplicas` | Minimum database replicas | `1` |
| `db.maxReplicas` | Maximum database replicas | `3` |
| `backend.image` | Backend Docker image | `leobgs/leocinema-backend:v2` |
| `frontend.image` | Frontend Docker image | `leobgs/leocinema-frontend:red` |

## 🎨 Frontend Themes

The frontend image supports three color themes, set at build time via the Docker tag:

| Tag | Theme |
|---|---|
| `:red` | Red (default) |
| `:green` | Green |
| `:blue` | Blue |

To switch themes, update `frontend.image` in `values.yaml`:

```yaml
frontend:
  image: leobgs/leocinema-frontend:green
```

## 📈 Monitoring (v2)

Optional observability layer, used on the EKS lab cluster:

- The backend serves Prometheus metrics at `/metrics` on its own port (`metrics.port`, `9091`), which the Ingress never routes.
- `metrics.serviceMonitor.enabled=true` creates a `ServiceMonitor`; it needs the Prometheus Operator CRDs, so it is off by default.
- `monitoring/kube-prometheus-stack-values.yaml` holds the kube-prometheus-stack values (sized for a small demo cluster, Prometheus without persistent storage).
- `monitoring/manifests/dashboards/leocinema-environments.json` is the Grafana dashboard; the `theme` label lets it filter by environment (red / green / blue).

> **Note:** the default backend image, `leobgs/leocinema-backend:v2`, is built from the current `app-leocinema-backend` source (Node 20) and serves `/metrics`. The older `:argocd` tag (2026-06-28) does not, so a ServiceMonitor pointed at it has nothing to scrape.

## 🌐 Accessing the Application

With Ingress enabled:
- **Frontend:** `http://<INGRESS-IP>`
- **Backend (health):** `http://<INGRESS-IP>/api/health`

Without Ingress (local port-forward):
```bash
kubectl port-forward svc/leocinema-frontend-svc 8485:80 -n leocinema
kubectl port-forward svc/leocinema-backend-svc 8687:80 -n leocinema
```

**Leonardo Borges** — [leonardobgsilva.github.io](https://leonardobgsilva.github.io)
