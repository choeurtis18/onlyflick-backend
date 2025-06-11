Write-Host "Verification complete du deploiement OnlyFlick" -ForegroundColor Green

Write-Host "`nEtat des ressources:" -ForegroundColor Yellow
kubectl get all -n onlyflick

Write-Host "`nIngress:" -ForegroundColor Yellow
kubectl get ingress -n onlyflick

Write-Host "`nTest des endpoints:" -ForegroundColor Yellow

$endpoints = @(
    "http://onlyflick.local",
    "http://api.onlyflick.local",
    "http://onlyflick.local/health",
    "http://api.onlyflick.local/health"
)

foreach ($endpoint in $endpoints) {
    try {
        $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec 5
        Write-Host "✅ $endpoint : $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "❌ $endpoint : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nURLs disponibles:" -ForegroundColor Green
Write-Host "  Frontend: http://onlyflick.local" -ForegroundColor Cyan
Write-Host "  API Backend: http://api.onlyflick.local" -ForegroundColor Cyan
Write-Host "  Health Check: http://onlyflick.local/health" -ForegroundColor Cyan
Write-Host "  API via Frontend: http://onlyflick.local/api/*" -ForegroundColor Cyan

Write-Host "`nOnlyFlick deploye avec succes!" -ForegroundColor Green
