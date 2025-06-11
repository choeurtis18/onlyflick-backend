Write-Host "Correction de l'erreur 503 Ingress" -ForegroundColor Red

# 1. Vérifier l'état de l'ingress controller
Write-Host "`n1. Verification ingress controller..." -ForegroundColor Yellow
kubectl get pods -n ingress-nginx
kubectl get services -n ingress-nginx

# 2. Supprimer et recréer l'ingress
Write-Host "`n2. Suppression ingress actuel..." -ForegroundColor Yellow
kubectl delete ingress onlyflick-ingress -n onlyflick

# 3. Créer un ingress simplifié pour test
Write-Host "`n3. Creation ingress simplifie..." -ForegroundColor Yellow
@"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: onlyflick-simple
  namespace: onlyflick
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: onlyflick.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: onlyflick-backend-service
            port:
              number: 80
"@ | kubectl apply -f -

# 4. Attendre la propagation
Write-Host "`n4. Attente propagation (10s)..." -ForegroundColor Yellow
Start-Sleep 10

# 5. Test du nouvel ingress
Write-Host "`n5. Test nouvel ingress..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://onlyflick.local" -UseBasicParsing -TimeoutSec 10
    Write-Host "✅ Ingress corrige: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "❌ Ingress toujours KO: $($_.Exception.Message)" -ForegroundColor Red
    
    # Logs de l'ingress controller
    Write-Host "`nLogs ingress controller:" -ForegroundColor Cyan
    kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=20
}

Write-Host "`nCorrection terminee!" -ForegroundColor Green
