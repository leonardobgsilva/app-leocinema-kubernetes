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
│       └── values.yaml   # Chart configuration
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

# Start the tunnel (keep this terminal open)
minikube tunnel

# Deploy (use 127.0.0.1 as ingressIp when using minikube tunnel)
helm install leocinema helm/leocinema/ \
  --namespace leocinema \
  --create-namespace \
  --set ingressIp="127.0.0.1" \
  --set nodeSelectorEnabled=false
```

> **Windows with Docker driver:** the Minikube IP (`minikube ip`) is not directly accessible from Windows. Use `minikube tunnel` and set `ingressIp` to `127.0.0.1`.

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
helm install leocinema helm/leocinema/ \
  --namespace leocinema \
  --create-namespace \
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

> Before applying, make sure `values.yaml` is configured correctly:
> - **Local (Minikube):** set `ingressIp` to `127.0.0.1`, run `minikube tunnel`, and set `nodeSelectorEnabled: false`
> - **Cloud:** set `ingressIp` to the external Ingress IP and optionally label your nodes with `tier=app` / `tier=db`

---

## 📄 Option 3 — Manifests (without Helm)

```bash
# Edit the Ingress IP in manifest-env.yaml before applying
# For local (Minikube): use 127.0.0.1 (with minikube tunnel) and remove the nodeSelector from backend, frontend and db manifests
kubectl apply -f manifests/manifest-env.yaml
kubectl apply -f manifests/manifest-db.yaml
kubectl apply -f manifests/manifest-backend.yaml
kubectl apply -f manifests/manifest-frontend.yaml
```

---

## ⚙️ Configuration (`values.yaml`)

| Parameter | Description | Default |
|---|---|---|
| `ingressEnabled` | Enables the external Ingress | `true` |
| `nodeSelectorEnabled` | Enables the nodeSelector | `true` |
| `ingressIp` | External Ingress IP | `<INGRESS-IP>` |
| `db.minReplicas` | Minimum database replicas | `1` |
| `db.maxReplicas` | Maximum database replicas | `15` |
| `backend.image` | Backend Docker image | `leobgs/leocinema-backend:argocd` |
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
