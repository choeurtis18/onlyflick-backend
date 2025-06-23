#!/bin/bash

# Script de setup du monitoring OnlyFlick pour macOS
# Équivalent exact de setup-monitoring.ps1

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() { echo -e "${GREEN}$1${NC}"; }
print_info() { echo -e "${YELLOW}$1${NC}"; }
print_cyan() { echo -e "${CYAN}$1${NC}"; }

print_step "Setup du monitoring OnlyFlick"

# Vérifier que Helm est installé
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm n'est pas installé${NC}"
    echo "Installation: brew install helm"
    exit 1
fi

# 1. Ajouter les repos Helm
echo ""
print_info "1. Configuration Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Vérifier si monitoring existe déjà
echo ""
print_info "2. Vérification installation existante..."

# Créer le namespace monitoring s'il n'existe pas
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Vérifier si la release monitoring existe (équivalent PowerShell)
existing_release=$(helm list -n monitoring -q | grep "monitoring" || echo "")

if [ -n "$existing_release" ]; then
    print_cyan "Monitoring déjà installé, mise à jour..."
    helm upgrade monitoring prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --set grafana.adminPassword=admin123 \
      --wait
else
    print_info "Installation Prometheus + Grafana..."
    helm install monitoring prometheus-community/kube-prometheus-stack \
      --namespace monitoring --create-namespace \
      --set grafana.adminPassword=admin123 \
      --wait
fi

# 3. Appliquer l'ingress Grafana
echo ""
print_info "3. Configuration ingress Grafana..."

# Créer le répertoire k8s/monitoring s'il n'existe pas
mkdir -p k8s/monitoring

# Créer le fichier grafana-ingress.yaml s'il n'existe pas
if [ ! -f "k8s/monitoring/grafana-ingress.yaml" ]; then
    cat > k8s/monitoring/grafana-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-grafana
            port:
              number: 80
EOF
fi

kubectl apply -f k8s/monitoring/grafana-ingress.yaml

# 4. Importer les dashboards
echo ""
print_info "4. Import dashboards..."
if [ -d "frontend/onlyflick-app/grafana/dashboards" ]; then
    print_cyan "Dashboards frontend détectés"
else
    print_info "Dashboards frontend manquants"
fi

echo ""
print_step "✅ Monitoring setup complet!"
print_cyan "Grafana: http://grafana.local (admin/admin123)"