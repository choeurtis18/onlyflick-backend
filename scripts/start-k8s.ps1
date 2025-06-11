# Script pour démarrer Kubernetes et vérifier la configuration

Write-Host "Démarrage de l'environnement Kubernetes OnlyFlick" -ForegroundColor Green

# Vérifier Docker Desktop
Write-Host "Vérification de Docker Desktop..." -ForegroundColor Yellow
try {
    docker info > $null
    Write-Host "Docker Desktop est en cours d'exécution" -ForegroundColor Green
} catch {
    Write-Host "Docker Desktop n'est pas en cours d'exécution" -ForegroundColor Red
    Write-Host "Veuillez démarrer Docker Desktop et activer Kubernetes" -ForegroundColor Yellow
    exit 1
}

# Vérifier Kubernetes
Write-Host "Vérification de Kubernetes..." -ForegroundColor Yellow
try {
    kubectl cluster-info --request-timeout=10s
    Write-Host "Kubernetes est accessible" -ForegroundColor Green
} catch {
    Write-Host "Kubernetes n'est pas accessible" -ForegroundColor Red
    Write-Host "Solutions possibles:" -ForegroundColor Yellow
    Write-Host "1. Ouvrir Docker Desktop" -ForegroundColor White
    Write-Host "2. Aller dans Settings > Kubernetes" -ForegroundColor White
    Write-Host "3. Cocher 'Enable Kubernetes'" -ForegroundColor White
    Write-Host "4. Cliquer sur 'Apply & Restart'" -ForegroundColor White
    exit 1
}

# Vérifier Helm
Write-Host "Vérification de Helm..." -ForegroundColor Yellow
try {
    helm version --short
    Write-Host "Helm est installé" -ForegroundColor Green
} catch {
    Write-Host "Helm n'est pas installé" -ForegroundColor Red
    Write-Host "Installer Helm: https://helm.sh/docs/intro/install/" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nEnvironnement prêt! Vous pouvez maintenant exécuter:" -ForegroundColor Green
Write-Host "  .\scripts\deploy-k8s.ps1" -ForegroundColor Cyan
