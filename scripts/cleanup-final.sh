#!/bin/bash

# 🧹 Script de nettoyage final OnlyFlick

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "\n${GREEN}$1${NC}"; }
print_info() { echo -e "${YELLOW}$1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }

print_step "🧹 Nettoyage final OnlyFlick"

# 1. État actuel
print_info "📋 1. État actuel du cluster..."
kubectl get pods -n onlyflick -o wide

# 2. Supprimer les anciens pods en erreur
print_info "🗑️ 2. Suppression des anciens pods en erreur..."
kubectl delete pod -n onlyflick -l app=onlyflick-backend --field-selector=status.phase=Failed 2>/dev/null || echo "Aucun pod Failed"
kubectl delete pod -n onlyflick onlyflick-backend-894bf477d-nmtzf --ignore-not-found=true

# 3. Attendre stabilisation
print_info "⏳ 3. Attente de la stabilisation..."
sleep 10

# 4. Vérifier les nouveaux pods
print_info "📊 4. Vérification des nouveaux pods..."
kubectl get pods -n onlyflick

# 5. Attendre que le nouveau backend soit prêt
print_info "⏳ 5. Attente du nouveau backend..."
kubectl wait --for=condition=ready pod -l app=onlyflick-backend -n onlyflick --timeout=60s

# 6. Vérifier les logs du nouveau backend
print_info "📋 6. Logs du nouveau backend..."
kubectl logs -n onlyflick -l app=onlyflick-backend --tail=20

# 7. Test de connectivité de l'API
print_info "🧪 7. Test de l'API..."
kubectl port-forward -n onlyflick svc/onlyflick-backend-service 8080:8080 &
PORT_FORWARD_PID=$!
sleep 5

echo "Test de l'endpoint health..."
if curl -f http://localhost:8080/health &> /dev/null; then
    response=$(curl -s http://localhost:8080/health)
    print_success "API Health Check: $response"
    
    echo -e "\nTest de l'endpoint racine..."
    root_response=$(curl -s http://localhost:8080/ | jq -r .message 2>/dev/null || curl -s http://localhost:8080/)
    print_success "API Root: $root_response"
else
    echo "❌ API Test: Échec"
    echo "Logs détaillés du backend:"
    kubectl logs -n onlyflick -l app=onlyflick-backend --tail=50
fi

kill $PORT_FORWARD_PID 2>/dev/null || true

# 8. Vérifier la connectivité PostgreSQL
print_info "🐘 8. Test de connectivité PostgreSQL..."
if kubectl exec -n onlyflick -l app=postgres -- pg_isready -U onlyflick_user -d onlyflick_db > /dev/null 2>&1; then
    print_success "PostgreSQL: Opérationnel"
else
    echo "❌ PostgreSQL: Problème de connectivité"
fi

# 9. État final des services
print_info "📊 9. État final des services..."
echo "Pods:"
kubectl get pods -n onlyflick
echo -e "\nServices:"
kubectl get svc -n onlyflick
echo -e "\nIngress:"
kubectl get ingress -n onlyflick

print_step "🎉 Nettoyage terminé!"
print_info "🌐 URLs à tester:"
echo "  • Frontend: http://onlyflick.local"
echo "  • API: http://api.onlyflick.local"
echo "  • API directe: kubectl port-forward -n onlyflick svc/onlyflick-backend-service 8080:8080"