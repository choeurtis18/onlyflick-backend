Write-Host "Déploiement OnlyFlick (mode sans validation)" -ForegroundColor Green

# 1. Créer le namespace
Write-Host "`nCréation du namespace..." -ForegroundColor Yellow
kubectl create namespace onlyflick --validate=false --dry-run=client -o yaml | kubectl apply -f - --validate=false

# 2. Créer le secret pour les variables d'environnement
Write-Host "`nCréation du secret backend..." -ForegroundColor Yellow
kubectl create secret generic onlyflick-backend-secret --from-env-file=.env -n onlyflick --validate=false

# 3. Build de l'image Docker
Write-Host "`nBuild de l'image Docker..." -ForegroundColor Yellow
docker build -t onlyflick-backend:latest .

# 4. Déploiement du backend
Write-Host "`nDéploiement du backend..." -ForegroundColor Yellow
kubectl apply -f k8s/backend/ --validate=false

# 5. Déploiement des ingress
Write-Host "`nDéploiement des ingress..." -ForegroundColor Yellow
kubectl apply -f k8s/ingress/ --validate=false

# 6. Vérifier le statut
Write-Host "`nStatut des déploiements:" -ForegroundColor Green
kubectl get all -n onlyflick

Write-Host "`nURLs d'accès:" -ForegroundColor Green
Write-Host "  Backend API: http://api.onlyflick.local" -ForegroundColor Cyan
Write-Host "  Health Check: http://api.onlyflick.local/health" -ForegroundColor Cyan

Write-Host "`nDéploiement terminé!" -ForegroundColor Green
