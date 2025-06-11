Write-Host "Diagnostic des erreurs 503 OnlyFlick" -ForegroundColor Red

Write-Host "`n1. Etat des pods:" -ForegroundColor Yellow
kubectl get pods -n onlyflick -o wide

Write-Host "`n2. Etat des services:" -ForegroundColor Yellow
kubectl get services -n onlyflick

Write-Host "`n3. Etat des ingress:" -ForegroundColor Yellow
kubectl get ingress -n onlyflick

Write-Host "`n4. Logs du backend:" -ForegroundColor Yellow
kubectl logs -n onlyflick -l app=onlyflick-backend --tail=10

Write-Host "`n5. Description du service backend:" -ForegroundColor Yellow
kubectl describe service onlyflick-backend-service -n onlyflick

Write-Host "`n6. Etat de l'ingress controller:" -ForegroundColor Yellow
kubectl get pods -n ingress-nginx

Write-Host "`n7. Test de conectivite directe:" -ForegroundColor Yellow
kubectl port-forward service/onlyflick-backend-service 8081:80 -n onlyflick --timeout=10s
