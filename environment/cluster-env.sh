#!/bin/bash

######## CREATE NAMESPACE LEOCINEMA ########

- kubectl create namespace leocinema

######## INSTALL NGINX INGRESS CONTROLLER & GET NGINX INGRESS IP ########

- kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
- kubectl apply -f get-ingress.yaml
- kubectl get ingresses #WAIT FOR THE IP ADDRESS TO APPEAR!
- kubectl delete -f get-ingress.yaml

######## INSTALL AND ACCESS ARGOCD ########

- kubectl create namespace argocd
- kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
- kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
- kubectl port-forward svc/argocd-server -n argocd 8080:443