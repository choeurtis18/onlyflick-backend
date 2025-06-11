Write-Host "Test complet de l'ingress OnlyFlick" -ForegroundColor Green

# 1. Vérifier que l'ingress controller fonctionne
Write-Host "`n1. Verification de l'ingress controller..." -ForegroundColor Yellow
kubectl get pods -n ingress-nginx
kubectl get services -n ingress-nginx

# 2. Vérifier la résolution DNS locale
Write-Host "`n2. Test de resolution DNS..." -ForegroundColor Yellow
try {
    $nslookup = nslookup onlyflick.local 2>$null
    if ($nslookup -match "127.0.0.1") {
        Write-Host "DNS local OK: onlyflick.local -> 127.0.0.1" -ForegroundColor Green
    } else {
        Write-Host "Probleme DNS: onlyflick.local ne pointe pas vers 127.0.0.1" -ForegroundColor Red
        Write-Host "Ajoutez dans C:\Windows\System32\drivers\etc\hosts:" -ForegroundColor Yellow
        Write-Host "127.0.0.1 onlyflick.local" -ForegroundColor White
        Write-Host "127.0.0.1 api.onlyflick.local" -ForegroundColor White
    }
} catch {
    Write-Host "Erreur lors du test DNS" -ForegroundColor Red
}

# 3. Test direct du service backend
Write-Host "`n3. Test direct du service backend..." -ForegroundColor Yellow
Write-Host "Demarrage port-forward..." -ForegroundColor Cyan

$job = Start-Job -ScriptBlock {
    kubectl port-forward service/onlyflick-backend-service 8082:80 -n onlyflick
}

Start-Sleep 5

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8082/health" -UseBasicParsing -TimeoutSec 10
    Write-Host "Service backend OK: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Service backend KO: $($_.Exception.Message)" -ForegroundColor Red
}

$job | Stop-Job
$job | Remove-Job

# 4. Test de l'ingress NGINX
Write-Host "`n4. Test de l'ingress via curl..." -ForegroundColor Yellow
try {
    # Test avec curl si disponible
    $curlTest = curl -s -o /dev/null -w "%{http_code}" http://onlyflick.local 2>$null
    if ($curlTest -eq "200") {
        Write-Host "Ingress OK: HTTP 200" -ForegroundColor Green
    } elseif ($curlTest -eq "503") {
        Write-Host "Ingress KO: HTTP 503 - Service unavailable" -ForegroundColor Red
    } else {
        Write-Host "Ingress reponse: HTTP $curlTest" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Curl non disponible, test avec PowerShell..." -ForegroundColor Yellow
    try {
        $webTest = Invoke-WebRequest -Uri "http://onlyflick.local" -UseBasicParsing -TimeoutSec 10
        Write-Host "Ingress OK: $($webTest.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "Ingress KO: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 5. Afficher la configuration actuelle
Write-Host "`n5. Configuration actuelle:" -ForegroundColor Yellow
Write-Host "Ingress:" -ForegroundColor Cyan
kubectl get ingress onlyflick-ingress -n onlyflick -o yaml

Write-Host "`nRecommandations:" -ForegroundColor Green
Write-Host "- Verifiez que Docker Desktop Kubernetes est active" -ForegroundColor White
Write-Host "- Verifiez le fichier hosts: C:\Windows\System32\drivers\etc\hosts" -ForegroundColor White
Write-Host "- Redemarrez Docker Desktop si necessaire" -ForegroundColor White
