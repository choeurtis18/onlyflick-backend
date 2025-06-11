Write-Host "Nettoyage des ingress OnlyFlick" -ForegroundColor Green

# Supprimer les anciens ingress
Write-Host "`nSuppression des anciens ingress..." -ForegroundColor Yellow
kubectl delete ingress onlyflick-simple -n onlyflick --ignore-not-found=true
kubectl delete ingress onlyflick-test-ingress -n onlyflick --ignore-not-found=true

# Appliquer l'ingress final
Write-Host "`nApplication ingress final..." -ForegroundColor Yellow
kubectl apply -f k8s/ingress/ingress.yaml

# Vérifier l'état
Write-Host "`nEtat des ingress:" -ForegroundColor Green
kubectl get ingress -n onlyflick

Write-Host "`nTest final:" -ForegroundColor Cyan
Write-Host "✅ Frontend: http://onlyflick.local" -ForegroundColor Green
Write-Host "✅ API: http://api.onlyflick.local" -ForegroundColor Green
Write-Host "✅ Health: http://onlyflick.local/health" -ForegroundColor Green
Write-Host "✅ API routes: http://onlyflick.local/api/*" -ForegroundColor Green

Write-Host "`nOnlyFlick est maintenant accessible!" -ForegroundColor Green
