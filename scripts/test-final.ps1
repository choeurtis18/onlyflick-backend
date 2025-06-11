Write-Host "Test final OnlyFlick avec route racine" -ForegroundColor Green

# 1. Appliquer l'ingress corrigé
Write-Host "`n1. Application ingress corrige..." -ForegroundColor Yellow
kubectl apply -f k8s/ingress/ingress.yaml

Start-Sleep 5

# 2. Test de la route racine via port-forward
Write-Host "`n2. Test route racine backend..." -ForegroundColor Yellow
$job = Start-Job -ScriptBlock {
    kubectl port-forward service/onlyflick-backend-service 8087:80 -n onlyflick
}

Start-Sleep 3

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8087/" -UseBasicParsing -TimeoutSec 5
    Write-Host "Route racine backend: ✅ $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Contenu: $($response.Content)" -ForegroundColor White
} catch {
    Write-Host "Route racine backend: ❌ $($_.Exception.Message)" -ForegroundColor Red
}

$job | Stop-Job
$job | Remove-Job

# 3. Test via ingress
Write-Host "`n3. Test via ingress..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://onlyflick.local" -UseBasicParsing -TimeoutSec 10
    Write-Host "Ingress principal: ✅ $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Ingress principal: ❌ $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Test API
try {
    $response = Invoke-WebRequest -Uri "http://api.onlyflick.local" -UseBasicParsing -TimeoutSec 10
    Write-Host "API ingress: ✅ $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "API ingress: ❌ $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Test health
try {
    $response = Invoke-WebRequest -Uri "http://onlyflick.local/health" -UseBasicParsing -TimeoutSec 10
    Write-Host "Health via ingress: ✅ $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Health via ingress: ❌ $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest final termine!" -ForegroundColor Cyan
