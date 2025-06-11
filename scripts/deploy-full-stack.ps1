Write-Host "Deploiement complet OnlyFlick Full-Stack" -ForegroundColor Green

# 1. Setup frontend
Write-Host "`n🧩 1. Setup Frontend Flutter..." -ForegroundColor Yellow
.\scripts\setup-frontend.ps1

# 2. Build et deploy backend
Write-Host "`n🔧 2. Deploy Backend..." -ForegroundColor Yellow
docker build -t onlyflick-backend:latest .
kubectl apply -f k8s/backend/

# 3. Deploy frontend
Write-Host "`n🎨 3. Deploy Frontend..." -ForegroundColor Yellow
kubectl apply -f k8s/frontend/

# 4. Update ingress
Write-Host "`n🌐 4. Update Ingress..." -ForegroundColor Yellow
kubectl apply -f k8s/ingress/ingress.yaml

# 5. Setup monitoring
Write-Host "`n📊 5. Setup Monitoring..." -ForegroundColor Yellow
.\scripts\setup-monitoring.ps1

# 6. Verification finale
Write-Host "`n✅ 6. Verification finale..." -ForegroundColor Yellow
Start-Sleep 10
.\scripts\verify-deployment.ps1

# 7. Tests E2E
Write-Host "`n🧪 7. Tests E2E..." -ForegroundColor Yellow
go test ./tests/e2e/frontend-backend-integration_test.go -v

Write-Host "`n🎉 OnlyFlick Full-Stack deploye avec succes!" -ForegroundColor Green
Write-Host "`nURLs disponibles:" -ForegroundColor Cyan
Write-Host "  Frontend: http://onlyflick.local" -ForegroundColor White
Write-Host "  API: http://api.onlyflick.local" -ForegroundColor White
Write-Host "  Grafana: http://grafana.local" -ForegroundColor White
