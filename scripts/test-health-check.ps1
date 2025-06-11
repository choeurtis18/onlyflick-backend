# Script PowerShell pour tester la santé des services OnlyFlick

Write-Host "🔍 Testing OnlyFlick Health Endpoints..." -ForegroundColor Cyan

# Test du backend via service interne Kubernetes
Write-Host "`n📡 Testing backend service (internal)..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://onlyflick-backend-service.onlyflick-staging.svc.cluster.local/health" -UseBasicParsing -TimeoutSec 10
    Write-Host "✅ Backend internal service: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Backend internal service failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test du backend via ingress local
Write-Host "`n🌐 Testing backend via ingress..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://api.onlyflick.local/health" -UseBasicParsing -TimeoutSec 10
    Write-Host "✅ Backend ingress: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Backend ingress failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test du frontend
Write-Host "`n🎨 Testing frontend..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://onlyflick.local" -UseBasicParsing -TimeoutSec 10
    Write-Host "✅ Frontend: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "❌ Frontend failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Afficher le statut des pods
Write-Host "`n📊 Kubernetes pods status:" -ForegroundColor Yellow
kubectl get pods -n onlyflick-staging

# Afficher les services
Write-Host "`n🔗 Kubernetes services:" -ForegroundColor Yellow
kubectl get services -n onlyflick-staging

Write-Host "`n✅ Health check completed!" -ForegroundColor Green
