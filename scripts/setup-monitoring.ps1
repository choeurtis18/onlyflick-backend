Write-Host "Setup du monitoring OnlyFlick" -ForegroundColor Green

# 1. Ajouter les repos Helm
Write-Host "`n1. Configuration Helm repositories..." -ForegroundColor Yellow
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Vérifier si monitoring existe déjà
Write-Host "`n2. Verification installation existante..." -ForegroundColor Yellow
$existingRelease = helm list -n monitoring -q | Where-Object { $_ -eq "monitoring" }

if ($existingRelease) {
    Write-Host "Monitoring deja installe, mise a jour..." -ForegroundColor Cyan
    helm upgrade monitoring prometheus-community/kube-prometheus-stack `
      --namespace monitoring `
      --set grafana.adminPassword=admin123 `
      --wait
} else {
    Write-Host "Installation Prometheus + Grafana..." -ForegroundColor Yellow
    helm install monitoring prometheus-community/kube-prometheus-stack `
      --namespace monitoring --create-namespace `
      --set grafana.adminPassword=admin123 `
      --wait
}

# 3. Appliquer l'ingress Grafana
Write-Host "`n3. Configuration ingress Grafana..." -ForegroundColor Yellow
kubectl apply -f k8s/monitoring/grafana-ingress.yaml

# 4. Importer les dashboards
Write-Host "`n4. Import dashboards..." -ForegroundColor Yellow
if (Test-Path "onlyflick-app/grafana/dashboards") {
    Write-Host "Dashboards frontend detectes" -ForegroundColor Cyan
} else {
    Write-Host "Dashboards frontend manquants" -ForegroundColor Yellow
}

Write-Host "`n✅ Monitoring setup complete!" -ForegroundColor Green
Write-Host "Grafana: http://grafana.local (admin/admin123)" -ForegroundColor Cyan
