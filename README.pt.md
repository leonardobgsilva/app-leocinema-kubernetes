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
│       ├── values.yaml        # Configurações do chart (perfil de produção)
│       └── values-local.yaml  # Perfil de laboratório local (Minikube)
├── monitoring/           # values do kube-prometheus-stack + dashboard do Grafana (v2)
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

# Aguarde o controller do NGINX ficar pronto antes de instalar o chart
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s

# Iniciar o tunnel (mantenha este terminal aberto)
minikube tunnel

# Deploy com o perfil de laboratório local: MariaDB dentro do cluster, frontend ligado,
# Secret e ConfigMap criados pelo Helm com credenciais de demonstração (veja values-local.yaml)
helm install leocinema helm/leocinema/ \
  --namespace leocinema \
  --create-namespace \
  -f helm/leocinema/values-local.yaml

# Conferir
kubectl get pods -n leocinema
curl http://127.0.0.1/api/health
```

> **Qual perfil?** O `values.yaml` padrão do chart é o **perfil de produção** (banco no RDS, Secret/ConfigMap gerenciados pelo Terraform, frontend em S3 + CloudFront). Sem essas peças, os pods do backend ficam em `CreateContainerConfigError`. Em um cluster simples use sempre o `values-local.yaml`.

> **Windows com driver Docker:** o IP do Minikube (`minikube ip`) não é acessível diretamente pelo Windows. Use `minikube tunnel` (o `values-local.yaml` já define `ingressIp` como `127.0.0.1`).

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
# (adicione --set nodeSelectorEnabled=true se você rotulou os nós)
helm install leocinema helm/leocinema/ \
  --namespace leocinema \
  --create-namespace \
  -f helm/leocinema/values-local.yaml \
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

> **Perfis:** a Application implanta o perfil padrão (produção) do chart, que espera receber banco, Secret e ConfigMap do Terraform. Em um cluster isolado (Minikube, ou laboratório sem Terraform) adicione o perfil local em `helm:` no `environment/argocd.yaml`:
>
> ```yaml
> helm:
>   valueFiles:
>     - values-local.yaml
>   parameters:
>     # ingressIp, nodeSelectorEnabled...
> ```
>
> - **Local (Minikube):** rode `minikube tunnel` e mantenha `ingressIp` como `127.0.0.1`
> - **Nuvem:** defina `ingressIp` com o IP externo do Ingress e opcionalmente rotule os nós com `tier=app` / `tier=db`

---

## 📄 Opção 3 — Manifests (sem Helm)

```bash
# O manifest-env.yaml traz credenciais de DEMONSTRAÇÃO (só para laboratório) e o IP do Ingress em 127.0.0.1 (minikube tunnel).
# Nuvem: edite o IP do Ingress ali. Local (Minikube): remova o nodeSelector dos manifests de backend, frontend e db.
kubectl apply -f manifests/manifest-env.yaml
kubectl apply -f manifests/manifest-db.yaml
kubectl apply -f manifests/manifest-backend.yaml
kubectl apply -f manifests/manifest-frontend.yaml
```

---

## ⚙️ Configurações (`values.yaml`)

| Parâmetro | Descrição | Padrão |
|---|---|---|
| `managedByTerraform` | Secret/ConfigMap vêm do Terraform (perfil de produção) | `true` |
| `createDb` | Roda o MariaDB dentro do cluster | `false` |
| `frontendEnabled` | Implanta o frontend no Kubernetes | `false` |
| `ingressEnabled` | Habilita o Ingress externo | `true` |
| `nodeSelectorEnabled` | Habilita o nodeSelector | `false` |
| `ingressIp` | IP externo do Ingress | `""` |
| `theme` | Tema da release (`red`/`green`/`blue`); prefixa o path do Ingress | `""` |
| `metrics.serviceMonitor.enabled` | Cria o ServiceMonitor do Prometheus | `false` |
| `db.minReplicas` | Réplicas mínimas do banco | `1` |
| `db.maxReplicas` | Réplicas máximas do banco | `3` |
| `backend.image` | Imagem Docker do backend | `leobgs/leocinema-backend:v2` |
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

## 📈 Monitoramento (v2)

Camada opcional de observabilidade, usada no cluster EKS de laboratório:

- O backend expõe métricas do Prometheus em `/metrics` em uma porta própria (`metrics.port`, `9091`), que o Ingress nunca roteia.
- `metrics.serviceMonitor.enabled=true` cria um `ServiceMonitor`; ele precisa dos CRDs do Prometheus Operator, por isso vem desligado por padrão.
- `monitoring/kube-prometheus-stack-values.yaml` traz os values do kube-prometheus-stack (dimensionado para um cluster de demonstração pequeno, Prometheus sem armazenamento persistente).
- `monitoring/manifests/dashboards/leocinema-environments.json` é o dashboard do Grafana; o label `theme` permite filtrar por ambiente (red / green / blue).

> **Nota:** a imagem padrão do backend, `leobgs/leocinema-backend:v2`, é gerada a partir do código atual do `app-leocinema-backend` (Node 20) e expõe `/metrics`. A tag antiga `:argocd` (28/06/2026) não expõe, então um ServiceMonitor apontado para ela não tem o que coletar.

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
