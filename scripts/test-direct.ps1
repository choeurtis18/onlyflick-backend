Write-Host "Test d'acces direct aux services OnlyFlick" -ForegroundColor Green

Write-Host "`nDemarrage port-forward backend..." -ForegroundColor Yellow
$backendJob = Start-Job -ScriptBlock {
    kubectl port-forward service/onlyflick-backend-service 8081:80 -n onlyflick
}

Start-Sleep 3

Write-Host "Test du backend..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8081/health" -UseBasicParsing -TimeoutSec 10
    Write-Host "Backend OK: Status $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Reponse: $($response.Content)" -ForegroundColor White
} catch {
    Write-Host "Backend KO: $($_.Exception.Message)" -ForegroundColor Red
}

$backendJob | Stop-Job
$backendJob | Remove-Job

Write-Host "`nDemarrage port-forward frontend..." -ForegroundColor Yellow
$frontendJob = Start-Job -ScriptBlock {
    kubectl port-forward service/onlyflick-frontend 8082:80 -n onlyflick
}

Start-Sleep 3

Write-Host "Test du frontend..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8082" -UseBasicParsing -TimeoutSec 10
    Write-Host "Frontend OK: Status $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Frontend KO: $($_.Exception.Message)" -ForegroundColor Red
}

$frontendJob | Stop-Job
$frontendJob | Remove-Job

Write-Host "`nTest de l'ingress..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://onlyflick.local" -UseBasicParsing -TimeoutSec 10
    Write-Host "Ingress OK: Status $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Ingress KO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Verifiez le fichier hosts et l'ingress controller" -ForegroundColor Yellow
}

Write-Host "`nResultats des tests termines." -ForegroundColor Green
