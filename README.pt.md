# 🎬 LeoCinema - Kubernetes

🇧🇷 Português | 🇺🇸 [English](README.md)

Deployment completo da aplicação **LeoCinema** no Kubernetes, com suporte a Helm Chart, ArgoCD (GitOps) e NGINX Ingress Controller.

## 🏗️ Arquitetura

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

## 📁 Estrutura do Projeto

```
app-leocinema-kubernetes/
├── environment/
│   ├── argocd.yaml       # Application ArgoCD (GitOps)
│   ├── cluster-env.sh    # Script de setup do cluster
│   └── get-ingress.yaml  # Helper para obter o IP do Ingress
├── helm/
│   └── leocinema/
│       ├── templates/    # Templates Kubernetes
│       │   ├── backend.yaml
│       │   ├── frontend.yaml
│       │   ├── db.yaml
│       │   └── env.yaml
│       ├── Chart.yaml
│       └── values.yaml   # Configurações do chart
└── manifests/            # Manifests Kubernetes sem Helm
    ├── manifest-backend.yaml
    ├── manifest-frontend.yaml
    ├── manifest-db.yaml
    └── manifest-env.yaml
```

## 🚀 Deploy

Escolha um dos três caminhos abaixo. Eles são independentes entre si.

---

## 💻 Opção 1 — Helm

### Local (Minikube)

```bash
# Instalar Minikube: https://minikube.sigs.k8s.io/docs/start/
minikube start
minikube addons enable ingress

# Iniciar o tunnel (mantenha este terminal aberto)
minikube tunnel

# Deploy (use 127.0.0.1 como ingressIp ao usar minikube tunnel)
helm install leocinema helm/leocinema/ \
  --namespace leocinema \
  --create-namespace \
  --set ingressIp="127.0.0.1" \
  --set nodeSelectorEnabled=false
```

> **Windows com driver Docker:** o IP do Minikube (`minikube ip`) não é acessível diretamente pelo Windows. Use `minikube tunnel` e defina `ingressIp` como `127.0.0.1`.

### Nuvem (EKS, GKE, AKS...)

```bash
# Instalar o NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Obter o IP externo do Ingress
kubectl apply -f environment/get-ingress.yaml
kubectl get ingresses  # aguarde o EXTERNAL-IP aparecer
kubectl delete -f environment/get-ingress.yaml

# Rotular os nós (opcional)
kubectl label node <nome-do-no> tier=app
kubectl label node <nome-do-no> tier=db

# Deploy
helm install leocinema helm/leocinema/ \
  --namespace leocinema \
  --create-namespace \
  --set ingressIp="<INGRESS-IP>"
```

---

## 🔄 Opção 2 — ArgoCD (GitOps)

O ArgoCD lê o Helm chart direto do repositório — não é necessário rodar o Helm localmente.

Antes de aplicar, edite o `environment/argocd.yaml` com os valores do seu ambiente:

```yaml
helm:
  parameters:
    - name: ingressIp
      value: "127.0.0.1"    # 127.0.0.1 para Minikube tunnel no Windows, ou IP externo da nuvem
    - name: nodeSelectorEnabled
      value: "false"         # false para Minikube, true para nuvem
```

```bash
# Criar namespace e instalar ArgoCD
kubectl create namespace argocd
kubectl apply \
  --server-side \
  --force-conflicts \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Obter senha do admin
# Linux/macOS:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# PowerShell:
[System.Text.Encoding]::UTF8.GetString(
    [System.Convert]::FromBase64String(
        (kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}")
    )
)

# Acessar o painel (http://localhost:8080)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Aplicar a Application do ArgoCD
kubectl apply -f environment/argocd.yaml
```

O ArgoCD vai sincronizar automaticamente com o repositório e manter o estado do cluster alinhado com o código.

> Antes de aplicar, certifique-se que o `values.yaml` está configurado corretamente:
> - **Local (Minikube):** defina `ingressIp` como `127.0.0.1`, rode `minikube tunnel` e defina `nodeSelectorEnabled: false`
> - **Nuvem:** defina `ingressIp` com o IP externo do Ingress e opcionalmente rotule os nós com `tier=app` / `tier=db`

---

## 📄 Opção 3 — Manifests (sem Helm)

```bash
# Edite o IP do Ingress no manifest-env.yaml antes de aplicar
# Para local (Minikube): use 127.0.0.1 (com minikube tunnel) e remova o nodeSelector dos manifests de backend, frontend e db
kubectl apply -f manifests/manifest-env.yaml
kubectl apply -f manifests/manifest-db.yaml
kubectl apply -f manifests/manifest-backend.yaml
kubectl apply -f manifests/manifest-frontend.yaml
```

---

## ⚙️ Configurações (`values.yaml`)

| Parâmetro | Descrição | Padrão |
|---|---|---|
| `ingressEnabled` | Habilita o Ingress externo | `true` |
| `nodeSelectorEnabled` | Habilita o nodeSelector | `true` |
| `ingressIp` | IP externo do Ingress | `<INGRESS-IP>` |
| `db.minReplicas` | Réplicas mínimas do banco | `1` |
| `db.maxReplicas` | Réplicas máximas do banco | `15` |
| `backend.image` | Imagem Docker do backend | `leobgs/leocinema-backend:argocd` |
| `frontend.image` | Imagem Docker do frontend | `leobgs/leocinema-frontend:red` |

## 🎨 Temas do Frontend

A imagem do frontend suporta três temas de cor, definidos em build time pela tag Docker:

| Tag | Tema |
|---|---|
| `:red` | Vermelho (padrão) |
| `:green` | Verde |
| `:blue` | Azul |

Para trocar o tema, atualize `frontend.image` no `values.yaml`:

```yaml
frontend:
  image: leobgs/leocinema-frontend:green
```

## 🌐 Acessando a Aplicação

Com Ingress habilitado:
- **Frontend:** `http://<INGRESS-IP>`
- **Backend (health):** `http://<INGRESS-IP>/api/health`

Sem Ingress (port-forward local):
```bash
kubectl port-forward svc/leocinema-frontend-svc 8485:80 -n leocinema
kubectl port-forward svc/leocinema-backend-svc 8687:80 -n leocinema
```

**Leonardo Borges** — [leonardobgsilva.github.io](https://leonardobgsilva.github.io)
