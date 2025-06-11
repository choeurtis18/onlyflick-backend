Write-Host "Correction de l'affichage Frontend Flutter" -ForegroundColor Green

# 1. Vérifier l'état du frontend
Write-Host "`n1. Verification du frontend..." -ForegroundColor Yellow
kubectl get pods -n onlyflick -l app=onlyflick-frontend
kubectl get services -n onlyflick | grep frontend

# 2. Corriger l'ingress pour pointer vers le frontend
Write-Host "`n2. Correction de l'ingress..." -ForegroundColor Yellow
@"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: onlyflick-ingress
  namespace: onlyflick
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS, PATCH"
    nginx.ingress.kubernetes.io/cors-allow-headers: "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization"
    nginx.ingress.kubernetes.io/enable-cors: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: api.onlyflick.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: onlyflick-backend-service
            port:
              number: 80
  - host: onlyflick.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: onlyflick-backend-service
            port:
              number: 80
      - path: /health
        pathType: Prefix
        backend:
          service:
            name: onlyflick-backend-service
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: onlyflick-frontend
            port:
              number: 80
"@ | kubectl apply -f -

# 3. Attendre la propagation
Write-Host "`n3. Attente propagation ingress..." -ForegroundColor Yellow
Start-Sleep 10

# 4. Test de l'affichage frontend
Write-Host "`n4. Test affichage frontend..." -ForegroundColor Yellow
try {
    $frontendResponse = Invoke-WebRequest -Uri "http://onlyflick.local" -UseBasicParsing -TimeoutSec 10
    if ($frontendResponse.Content -like "*flutter*" -or $frontendResponse.Content -like "*<!DOCTYPE html>*") {
        Write-Host "✅ Interface Flutter affichée!" -ForegroundColor Green
    } else {
        Write-Host "❌ Toujours JSON backend - frontend non configuré" -ForegroundColor Red
        Write-Host "Contenu reçu: $($frontendResponse.Content.Substring(0, 100))..." -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Erreur accès frontend: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 Pour voir l'interface Flutter:" -ForegroundColor Cyan
Write-Host "Ouvrir: http://onlyflick.local" -ForegroundColor White
Write-Host "Si toujours JSON, le frontend Flutter doit être déployé" -ForegroundColor Yellow
