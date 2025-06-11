Write-Host "Correction de la configuration ingress" -ForegroundColor Green

# 1. Supprimer l'ancien ingress
Write-Host "`n1. Suppression ancien ingress..." -ForegroundColor Yellow
kubectl delete ingress onlyflick-ingress -n onlyflick --ignore-not-found=true

# 2. Appliquer le nouveau ingress
Write-Host "`n2. Application nouveau ingress..." -ForegroundColor Yellow
kubectl apply -f k8s/ingress/ingress.yaml

# 3. Attendre que l'ingress soit prêt
Write-Host "`n3. Attente configuration ingress..." -ForegroundColor Yellow
Start-Sleep 10

# 4. Vérifier l'état
Write-Host "`n4. Verification etat ingress:" -ForegroundColor Yellow
kubectl get ingress -n onlyflick
kubectl describe ingress onlyflick-ingress -n onlyflick

# 5. Test final
Write-Host "`n5. Test des URLs:" -ForegroundColor Green
Write-Host "Frontend: http://onlyflick.local" -ForegroundColor Cyan
Write-Host "API: http://api.onlyflick.local/health" -ForegroundColor Cyan
Write-Host "Backend via frontend: http://onlyflick.local/api/health" -ForegroundColor Cyan

Write-Host "`nIngress corrige!" -ForegroundColor Green
