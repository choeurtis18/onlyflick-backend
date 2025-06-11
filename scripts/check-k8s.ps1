Write-Host "🔍 Diagnostic Kubernetes pour OnlyFlick" -ForegroundColor Green

# Vérifier Docker
Write-Host "`n📋 Étape 1: Vérification Docker Desktop" -ForegroundColor Yellow
try {
    $dockerInfo = docker info 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker Desktop fonctionne" -ForegroundColor Green
    } else {
        throw "Docker not running"
    }
} catch {
    Write-Host "❌ Docker Desktop n'est pas démarré" -ForegroundColor Red
    Write-Host "   Veuillez démarrer Docker Desktop" -ForegroundColor Yellow
    exit 1
}

# Vérifier Kubernetes
Write-Host "`n📋 Étape 2: Vérification Kubernetes" -ForegroundColor Yellow
try {
    kubectl cluster-info --request-timeout=5s 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Kubernetes est accessible" -ForegroundColor Green
    } else {
        throw "K8s not accessible"
    }
} catch {
    Write-Host "❌ Kubernetes n'est pas accessible" -ForegroundColor Red
    Write-Host "   Solutions:" -ForegroundColor Yellow
    Write-Host "   1. Ouvrir Docker Desktop" -ForegroundColor White
    Write-Host "   2. Settings > Kubernetes" -ForegroundColor White
    Write-Host "   3. Enable Kubernetes ✓" -ForegroundColor White
    Write-Host "   4. Apply & Restart" -ForegroundColor White
    Write-Host "   5. Attendre le démarrage (~2-3 minutes)" -ForegroundColor White
    exit 1
}

# Vérifier les contextes
Write-Host "`n📋 Étape 3: Contexte Kubernetes" -ForegroundColor Yellow
$currentContext = kubectl config current-context
Write-Host "   Contexte actuel: $currentContext" -ForegroundColor Cyan

# Vérifier les nodes
Write-Host "`n📋 Étape 4: Nodes disponibles" -ForegroundColor Yellow
kubectl get nodes

Write-Host "`n✅ Diagnostic terminé - Kubernetes est prêt!" -ForegroundColor Green
Write-Host "🚀 Vous pouvez maintenant déployer OnlyFlick" -ForegroundColor Cyan
