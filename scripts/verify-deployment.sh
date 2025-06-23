#!/bin/bash

# Script de vérification complète du déploiement OnlyFlick pour macOS
# Équivalent exact de verify-deployment.ps1

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

print_step() { echo -e "${GREEN}$1${NC}"; }
print_info() { echo -e "${YELLOW}$1${NC}"; }
print_cyan() { echo -e "${CYAN}$1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

print_step "Vérification complète du déploiement OnlyFlick"

# État des ressources
echo ""
print_info "État des ressources:"
kubectl get all -n onlyflick

# Ingress
echo ""
print_info "Ingress:"
kubectl get ingress -n onlyflick

# Test des endpoints
echo ""
print_info "Test des endpoints:"

# Liste des endpoints à tester
endpoints=(
    "http://onlyflick.local"
    "http://api.onlyflick.local"
    "http://onlyflick.local/health"
    "http://api.onlyflick.local/health"
)

# Fonction pour tester un endpoint
test_endpoint() {
    local url=$1
    local timeout=5
    
    # Tester avec curl
    if response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $timeout --max-time $timeout "$url" 2>/dev/null); then
        if [[ "$response" =~ ^[2-3][0-9][0-9]$ ]]; then
            print_success "$url : $response"
            return 0
        else
            print_error "$url : HTTP $response"
            return 1
        fi
    else
        print_error "$url : Connection failed"
        return 1
    fi
}

# Tester chaque endpoint
for endpoint in "${endpoints[@]}"; do
    test_endpoint "$endpoint"
done

# URLs disponibles
echo ""
print_step "URLs disponibles:"
print_cyan "  Frontend: http://onlyflick.local"
print_cyan "  API Backend: http://api.onlyflick.local"
print_cyan "  Health Check: http://onlyflick.local/health"
print_cyan "  API via Frontend: http://onlyflick.local/api/*"

echo ""
print_step "OnlyFlick déployé avec succès!"

# Tests supplémentaires spécifiques
echo ""
print_info "Tests supplémentaires:"

# Test spécifique de l'API health
echo ""
print_info "🏥 Test détaillé de l'API Health..."

# Port-forward pour tester directement le service
kubectl port-forward -n onlyflick svc/onlyflick-backend-service 8080:8080 &
PORT_FORWARD_PID=$!

# Attendre que le port-forward s'établisse
sleep 3

# Tester l'API directement
if health_response=$(curl -s http://localhost:8080/health 2>/dev/null); then
    print_success "API Health directe: $health_response"
else
    print_error "API Health directe: Non accessible"
fi

# Tester l'API root
if root_response=$(curl -s http://localhost:8080/ 2>/dev/null); then
    print_success "API Root directe: Accessible"
else
    print_error "API Root directe: Non accessible"
fi

# Arrêter le port-forward
kill $PORT_FORWARD_PID 2>/dev/null || true

# Vérifications des pods et services
echo ""
print_info "🔍 État détaillé des composants:"

# Vérifier les pods
backend_pods=$(kubectl get pods -n onlyflick -l app=onlyflick-backend --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$backend_pods" -gt 0 ]; then
    print_success "Backend pods: $backend_pods running"
else
    print_error "Backend pods: 0 running"
    echo ""
    print_info "📝 Logs du backend (dernières 10 lignes):"
    kubectl logs -n onlyflick -l app=onlyflick-backend --tail=10 2>/dev/null || echo "Aucun log disponible"
fi

# Vérifier les services
backend_services=$(kubectl get svc -n onlyflick -l app=onlyflick-backend --no-headers 2>/dev/null | wc -l)
if [ "$backend_services" -gt 0 ]; then
    print_success "Backend services: $backend_services configuré(s)"
else
    print_error "Backend services: 0 configuré"
fi

# Vérifier l'ingress
ingress_count=$(kubectl get ingress -n onlyflick --no-headers 2>/dev/null | wc -l)
if [ "$ingress_count" -gt 0 ]; then
    print_success "Ingress: $ingress_count configuré(s)"
else
    print_error "Ingress: 0 configuré"
fi

# Vérifier le monitoring (si installé)
echo ""
print_info "📊 Vérification du monitoring:"

if kubectl get namespace monitoring &>/dev/null; then
    grafana_pods=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    prometheus_pods=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    if [ "$grafana_pods" -gt 0 ]; then
        print_success "Grafana: Running (http://localhost:30080)"
    else
        print_error "Grafana: Not running"
    fi
    
    if [ "$prometheus_pods" -gt 0 ]; then
        print_success "Prometheus: Running"
    else
        print_error "Prometheus: Not running"
    fi
else
    print_error "Monitoring: Namespace non trouvé"
fi

# Informations pour le debugging
echo ""
print_info "🛠️  Commandes utiles pour le debugging:"
echo "  kubectl describe pod -n onlyflick -l app=onlyflick-backend"
echo "  kubectl logs -n onlyflick -l app=onlyflick-backend -f"
echo "  kubectl get events -n onlyflick --sort-by='.lastTimestamp'"
echo "  kubectl port-forward -n onlyflick svc/onlyflick-backend-service 8080:8080"

echo ""
print_info "🌐 Accès aux services:"
echo "  curl http://localhost:8080/health  # (après port-forward)"
echo "  curl http://api.onlyflick.local/health  # (via ingress)"

# Résumé final avec code de sortie
echo ""
failed_tests=0

# Compter les échecs
for endpoint in "${endpoints[@]}"; do
    if ! test_endpoint "$endpoint" >/dev/null 2>&1; then
        ((failed_tests++))
    fi
done

if [ $failed_tests -eq 0 ] && [ "$backend_pods" -gt 0 ]; then
    print_step "🎉 Tous les tests sont passés ! OnlyFlick est déployé avec succès !"
    exit 0
else
    echo ""
    print_error "⚠️  $failed_tests test(s) ont échoué. Vérifiez les logs ci-dessus."
    exit 1
fi