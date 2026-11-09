#!/bin/bash
# Cluster bootstrap helper: namespace, NGINX Ingress Controller, Ingress IP and ArgoCD.
# Run it from anywhere; it changes to this script's folder first.
set -euo pipefail
cd "$(dirname "$0")"

######## CREATE NAMESPACE LEOCINEMA ########

kubectl create namespace leocinema --dry-run=client -o yaml | kubectl apply -f -

######## INSTALL NGINX INGRESS CONTROLLER & GET NGINX INGRESS IP ########

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=180s
kubectl apply -f get-ingress.yaml
kubectl get ingresses   # WAIT FOR THE IP ADDRESS TO APPEAR!
read -rp "Copy the IP above, then press Enter to remove the helper Ingress... "
kubectl delete -f get-ingress.yaml

######## INSTALL AND ACCESS ARGOCD ########

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply \
  --server-side \
  --force-conflicts \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# Dashboard at https://localhost:8080 (keep this terminal open)
kubectl port-forward svc/argocd-server -n argocd 8080:443
