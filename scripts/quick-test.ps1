Write-Host "Test rapide OnlyFlick" -ForegroundColor Green

# Port-forward en arrière-plan
Write-Host "Demarrage port-forward..." -ForegroundColor Yellow
$job = Start-Job -ScriptBlock {
    kubectl port-forward service/onlyflick-backend-service 8086:80 -n onlyflick
}

Start-Sleep 5

# Test direct
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8086/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "Backend direct: ✅ $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Backend direct: ❌ $($_.Exception.Message)" -ForegroundColor Red
}

$job | Stop-Job
$job | Remove-Job

# Test ingress
try {
    $response = Invoke-WebRequest -Uri "http://onlyflick.local" -UseBasicParsing -TimeoutSec 5
    Write-Host "Ingress: ✅ $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Ingress: ❌ $($_.Exception.Message)" -ForegroundColor Red
    
    # Diagnostic détaillé de l'ingress
    Write-Host "`nDiagnostic ingress:" -ForegroundColor Yellow
    kubectl describe ingress onlyflick-ingress -n onlyflick
    
    Write-Host "`nBackends de l'ingress:" -ForegroundColor Yellow
    kubectl get ingress onlyflick-ingress -n onlyflick -o yaml
}

# Test API directe
Write-Host "`nTest API directe..." -ForegroundColor Yellow
try {
    $apiResponse = Invoke-WebRequest -Uri "http://api.onlyflick.local/health" -UseBasicParsing -TimeoutSec 5
    Write-Host "API directe: ✅ $($apiResponse.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "API directe: ❌ $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Test termine!" -ForegroundColor Cyan
