#!/bin/bash

# 🔧 Script de correction OnlyFlick - Résolution des problèmes de base de données

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "\n${GREEN}$1${NC}"; }
print_info() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }

print_step "🔧 Correction OnlyFlick - Déploiement PostgreSQL"

# 1. Diagnostic initial
print_info "📋 1. Diagnostic initial..."
echo "État actuel des pods:"
kubectl get pods -n onlyflick

echo -e "\nLogs du backend (dernières lignes):"
kubectl logs -n onlyflick -l app=onlyflick-backend --tail=10 || echo "Pas de logs disponibles"

# 2. Créer le répertoire k8s/database
print_info "📁 2. Création du répertoire database..."
mkdir -p k8s/database

# 3. Déployer PostgreSQL
print_info "🐘 3. Déploiement de PostgreSQL..."
cat > k8s/database/postgres-deployment.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: onlyflick
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: onlyflick
data:
  POSTGRES_DB: onlyflick_db
  POSTGRES_USER: onlyflick_user
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: onlyflick
type: Opaque
data:
  POSTGRES_PASSWORD: b25seWZsaWNrX3Bhc3N3b3Jk
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: onlyflick
  labels:
    app: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
          name: postgres
        envFrom:
        - configMapRef:
            name: postgres-config
        - secretRef:
            name: postgres-secret
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - onlyflick_user
            - -d
            - onlyflick_db
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - onlyflick_user
            - -d
            - onlyflick_db
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: onlyflick
  labels:
    app: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
    name: postgres
  type: ClusterIP
EOF

kubectl apply -f k8s/database/postgres-deployment.yaml
print_success "PostgreSQL déployé"

# 4. Attendre que PostgreSQL soit prêt
print_info "⏳ 4. Attente du démarrage de PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgres -n onlyflick --timeout=120s

# 5. Redémarrer le backend
print_info "🔄 5. Redémarrage du backend..."
kubectl rollout restart deployment/onlyflick-backend -n onlyflick

# 6. Attendre que le backend soit prêt
print_info "⏳ 6. Attente du démarrage du backend..."
kubectl wait --for=condition=ready pod -l app=onlyflick-backend -n onlyflick --timeout=120s

# 7. Vérification finale
print_info "✅ 7. Vérification finale..."
sleep 10

echo "État des pods:"
kubectl get pods -n onlyflick

echo -e "\nServices:"
kubectl get svc -n onlyflick

# 8. Test de l'API
print_info "🧪 8. Test de l'API..."
kubectl port-forward -n onlyflick svc/onlyflick-backend-service 8080:8080 &
PORT_FORWARD_PID=$!
sleep 5

if curl -f http://localhost:8080/health &> /dev/null; then
    response=$(curl -s http://localhost:8080/health)
    print_success "API Test: $response"
else
    print_error "API Test: KO - Vérifiez les logs"
fi

kill $PORT_FORWARD_PID 2>/dev/null || true

# 9. Affichage des logs pour diagnostic
print_info "📋 9. Logs du backend (vérification):"
kubectl logs -n onlyflick -l app=onlyflick-backend --tail=20

print_step "🎉 Correction terminée!"
echo ""
print_info "🌐 URLs à tester:"
echo -e "  Frontend: http://onlyflick.local"
echo -e "  API: http://api.onlyflick.local"
echo -e "  API directe: kubectl port-forward -n onlyflick svc/onlyflick-backend-service 8080:8080"
echo ""
print_info "📝 Commandes de diagnostic:"
echo -e "  kubectl get pods -n onlyflick"
echo -e "  kubectl logs -n onlyflick -l app=onlyflick-backend -f"
echo -e "  curl http://localhost:8080/health"