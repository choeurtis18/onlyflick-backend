Write-Host "Test rapide de connectivite OnlyFlick" -ForegroundColor Green

# 1. Test direct backend via port-forward
Write-Host "`n1. Test backend direct..." -ForegroundColor Yellow
$backendJob = Start-Job -ScriptBlock {
    kubectl port-forward service/onlyflick-backend-service 8083:80 -n onlyflick
}

Start-Sleep 5

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8083/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "✅ Backend accessible: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Reponse: $($response.Content)" -ForegroundColor White
} catch {
    Write-Host "❌ Backend inaccessible: $($_.Exception.Message)" -ForegroundColor Red
}

$backendJob | Stop-Job
$backendJob | Remove-Job

# 2. Appliquer la configuration ingress corrigée
Write-Host "`n2. Application de l'ingress corrige..." -ForegroundColor Yellow
kubectl apply -f k8s/ingress/ingress.yaml

Start-Sleep 3

# 3. Test via ingress
Write-Host "`n3. Test via ingress..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://onlyflick.local" -UseBasicParsing -TimeoutSec 10
    Write-Host "✅ Ingress accessible: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "❌ Ingress inaccessible: $($_.Exception.Message)" -ForegroundColor Red
    
    # Diagnostic supplémentaire
    Write-Host "`nDiagnostic ingress:" -ForegroundColor Cyan
    kubectl describe ingress onlyflick-ingress -n onlyflick
}

# 4. Test API directe
Write-Host "`n4. Test API via ingress..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://api.onlyflick.local/health" -UseBasicParsing -TimeoutSec 10
    Write-Host "✅ API accessible: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "❌ API inaccessible: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest termine!" -ForegroundColor Green
