#!/bin/bash
set -e

echo "🔧 Installation de Grafana avec Helm..."

# Ajouter le repo Helm de Grafana s'il n'existe pas déjà
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Créer le namespace si nécessaire
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Installation de Grafana avec les valeurs personnalisées
helm install grafana grafana/grafana \
  --namespace monitoring \
  --values k8s/monitoring/grafana-values.yaml

echo "⌛ Attente du déploiement de Grafana..."
kubectl rollout status deployment/grafana -n monitoring

echo "🚀 Déploiement de l'Ingress Grafana..."
kubectl apply -f k8s/monitoring/grafana-ingress.yaml

echo "✅ Installation terminée!"
echo ""
echo "📝 Accédez à Grafana via: http://grafana.local"
echo "🔑 Nom d'utilisateur: admin"
echo "🔑 Mot de passe: $(kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode)"
