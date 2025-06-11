# Script de déploiement Kubernetes pour OnlyFlick

Write-Host "🚀 Déploiement OnlyFlick sur Kubernetes" -ForegroundColor Green

# Vérifier que kubectl fonctionne
Write-Host "🔍 Vérification de kubectl..." -ForegroundColor Yellow
try {
    kubectl cluster-info --request-timeout=5s
    Write-Host "✅ Kubernetes est accessible" -ForegroundColor Green
} catch {
    Write-Host "❌ Erreur: Kubernetes n'est pas accessible" -ForegroundColor Red
    Write-Host "Veuillez démarrer Kubernetes dans Docker Desktop" -ForegroundColor Yellow
    exit 1
}

# Créer le namespace
Write-Host "📁 Création du namespace onlyflick..." -ForegroundColor Yellow
kubectl create namespace onlyflick --dry-run=client -o yaml | kubectl apply -f -

# Créer le secret pour les variables d'environnement
Write-Host "🔐 Création du secret pour le backend..." -ForegroundColor Yellow
kubectl create secret generic onlyflick-backend-secret --from-env-file=.env -n onlyflick --dry-run=client -o yaml | kubectl apply -f -

# Build de l'image Docker
Write-Host "🐳 Build de l'image Docker..." -ForegroundColor Yellow
docker build -t onlyflick-backend:latest .

# Déploiement du backend
Write-Host "🔧 Déploiement du backend..." -ForegroundColor Yellow
kubectl apply -f k8s/backend/onlyflick-backend-deployment.yaml
kubectl apply -f k8s/backend/onlyflick-backend-service.yaml

# Installer NGINX Ingress Controller si nécessaire
Write-Host "🌐 Installation de NGINX Ingress Controller..." -ForegroundColor Yellow
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Attendre que l'ingress controller soit prêt
Write-Host "⏳ Attente du démarrage de l'ingress controller..." -ForegroundColor Yellow
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s

# Déploiement des ingress
Write-Host "🌍 Déploiement des ingress..." -ForegroundColor Yellow
kubectl apply -f k8s/ingress/onlyflick-ingress.yaml

# Installation de Prometheus et Grafana
Write-Host "📊 Installation de Prometheus et Grafana..." -ForegroundColor Yellow
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --wait

# Déploiement de l'ingress Grafana
Write-Host "📈 Configuration de l'ingress Grafana..." -ForegroundColor Yellow
kubectl apply -f k8s/monitoring/grafana-ingress.yaml

# Afficher les statuts
Write-Host "`n🎯 Statuts des déploiements:" -ForegroundColor Green
kubectl get pods -n onlyflick
kubectl get services -n onlyflick
kubectl get ingress -n onlyflick

Write-Host "`n🌐 URLs d'accès:" -ForegroundColor Green
Write-Host "  Backend API: http://api.onlyflick.local" -ForegroundColor Cyan
Write-Host "  Frontend: http://onlyflick.local" -ForegroundColor Cyan
Write-Host "  Grafana: http://grafana.local" -ForegroundColor Cyan

Write-Host "`n✅ Déploiement terminé!" -ForegroundColor Green
