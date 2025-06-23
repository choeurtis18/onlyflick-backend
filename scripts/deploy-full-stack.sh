#!/bin/bash

# Script de déploiement complet OnlyFlick Full-Stack pour macOS
# Version corrigée - résout les problèmes de namespace

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

print_step() { echo -e "\n${GREEN}$1${NC}"; }
print_info() { echo -e "${YELLOW}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }

print_step "Déploiement complet OnlyFlick Full-Stack"

# Vérification des prérequis
echo ""
print_info "🔍 Vérification des prérequis..."

if ! command -v kubectl &> /dev/null; then
    print_error "❌ kubectl n'est pas installé"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "❌ Docker n'est pas installé"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "❌ Kubernetes cluster non accessible"
    exit 1
fi

print_success "Tous les prérequis sont installés"

# 1. Setup frontend
echo ""
print_info "🧩 1. Setup Frontend Flutter..."
if [ -f "scripts/setup-frontend.sh" ]; then
    chmod +x scripts/setup-frontend.sh
    ./scripts/setup-frontend.sh
else
    print_info "⚠️  Script setup-frontend.sh non trouvé, ignoré"
fi

# 2. Build et deploy backend
echo ""
print_info "🔧 2. Deploy Backend..."

# Nettoyer complètement les namespaces existants
print_info "🧹 Nettoyage des namespaces existants..."
kubectl delete namespace onlyflick --ignore-not-found=true
kubectl delete namespace onlyflick-staging --ignore-not-found=true
sleep 3

# Créer un namespace propre
print_info "📁 Création du namespace onlyflick..."
kubectl create namespace onlyflick

# Build de l'image Docker
print_info "🔨 Build de l'image backend..."
docker build -t onlyflick-backend:latest .

# Créer les secrets
print_info "🔐 Création des secrets..."
kubectl create secret generic onlyflick-backend-secret \
    --from-literal=DATABASE_URL="postgres://onlyflick_user:onlyflick_password@postgres:5432/onlyflick_db?sslmode=disable" \
    --from-literal=SECRET_KEY="onlyflick-super-secret-jwt-key-change-this-in-production-32-chars-min-2024" \
    --from-literal=IMAGEKIT_PUBLIC_KEY="demo_public_key" \
    --from-literal=IMAGEKIT_PRIVATE_KEY="demo_private_key" \
    --from-literal=IMAGEKIT_URL_ENDPOINT="https://ik.imagekit.io/demo" \
    --from-literal=STRIPE_SECRET_KEY="sk_test_demo_key" \
    --from-literal=PORT="8080" \
    --from-literal=ENVIRONMENT="production" \
    --namespace=onlyflick

# Créer les manifests backend PROPRES (sans variables non résolues)
print_info "📝 Création des manifests backend..."
mkdir -p k8s/backend

cat > k8s/backend/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: onlyflick-backend
  namespace: onlyflick
  labels:
    app: onlyflick-backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: onlyflick-backend
  template:
    metadata:
      labels:
        app: onlyflick-backend
    spec:
      containers:
      - name: onlyflick-backend
        image: onlyflick-backend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 8080
          name: http
        envFrom:
        - secretRef:
            name: onlyflick-backend-secret
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: onlyflick-backend-service
  namespace: onlyflick
  labels:
    app: onlyflick-backend
spec:
  selector:
    app: onlyflick-backend
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
    name: http
  type: ClusterIP
EOF

# Appliquer les manifests backend
kubectl apply -f k8s/backend/deployment.yaml
print_success "Backend déployé"

# 3. Deploy frontend
echo ""
print_info "🎨 3. Deploy Frontend..."

mkdir -p k8s/frontend
cat > k8s/frontend/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: onlyflick-frontend
  namespace: onlyflick
  labels:
    app: onlyflick-frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: onlyflick-frontend
  template:
    metadata:
      labels:
        app: onlyflick-frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: onlyflick
data:
  default.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
            try_files $uri $uri/ /index.html;
        }
        
        location /health {
            return 200 'Frontend OK';
            add_header Content-Type text/plain;
        }
    }
---
apiVersion: v1
kind: Service
metadata:
  name: onlyflick-frontend-service
  namespace: onlyflick
  labels:
    app: onlyflick-frontend
spec:
  selector:
    app: onlyflick-frontend
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  type: ClusterIP
EOF

kubectl apply -f k8s/frontend/deployment.yaml
print_success "Frontend déployé"

# 4. Update ingress
echo ""
print_info "🌐 4. Update Ingress..."

# Installer NGINX Ingress Controller si nécessaire
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    print_info "📦 Installation de NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    
    print_info "⏳ Attente de l'ingress controller..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
else
    print_success "NGINX Ingress Controller déjà installé"
fi

# Créer l'ingress PROPRE
mkdir -p k8s/ingress
cat > k8s/ingress/ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: onlyflick-ingress
  namespace: onlyflick
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
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
            name: onlyflick-frontend-service
            port:
              number: 80
  - host: api.onlyflick.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: onlyflick-backend-service
            port:
              number: 8080
EOF

kubectl apply -f k8s/ingress/ingress.yaml
print_success "Ingress configuré"

# 5. Setup monitoring
echo ""
print_info "📊 5. Setup Monitoring..."

if [ -f "scripts/setup-monitoring.sh" ]; then
    chmod +x scripts/setup-monitoring.sh
    ./scripts/setup-monitoring.sh
else
    print_info "⚠️  Script setup-monitoring.sh non trouvé, ignoré"
fi

# 6. Vérification finale
echo ""
print_info "✅ 6. Vérification finale..."

print_info "⏳ Attente du démarrage des pods..."
kubectl wait --for=condition=ready pod -l app=onlyflick-backend -n onlyflick --timeout=120s || print_info "⚠️  Backend pas encore prêt"
kubectl wait --for=condition=ready pod -l app=onlyflick-frontend -n onlyflick --timeout=60s || print_info "⚠️  Frontend pas encore prêt"

sleep 10

if [ -f "scripts/verify-deployment.sh" ]; then
    chmod +x scripts/verify-deployment.sh
    ./scripts/verify-deployment.sh
else
    print_info "📊 Statut des pods:"
    kubectl get pods -n onlyflick
    echo ""
    print_info "📊 Statut des services:"
    kubectl get svc -n onlyflick
    echo ""
    print_info "📊 Statut des ingress:"
    kubectl get ingress -n onlyflick
fi

# 7. Tests E2E
echo ""
print_info "🧪 7. Tests E2E..."

if [ -f "tests/e2e/frontend-backend-integration_test.go" ] && command -v go &> /dev/null; then
    print_info "🧪 Lancement des tests E2E Go..."
    go test ./tests/e2e/frontend-backend-integration_test.go -v || print_info "⚠️  Tests E2E échoués (non bloquant)"
else
    print_info "🧪 Tests basiques de connectivité..."
    
    # Test direct du service backend
    kubectl port-forward -n onlyflick svc/onlyflick-backend-service 8080:8080 &
    PORT_FORWARD_PID=$!
    sleep 3
    
    if curl -f http://localhost:8080/health &> /dev/null; then
        response=$(curl -s http://localhost:8080/health)
        print_success "Test API directe: $response"
    else
        print_error "Test API directe: KO"
    fi
    
    kill $PORT_FORWARD_PID 2>/dev/null || true
fi

# Message final de succès
echo ""
print_step "🎉 OnlyFlick Full-Stack déployé avec succès!"
echo ""
print_info "🌐 URLs disponibles:"
echo -e "${WHITE}  Frontend: http://onlyflick.local${NC}"
echo -e "${WHITE}  API: http://api.onlyflick.local${NC}"
echo -e "${WHITE}  Grafana: http://grafana.local (admin/admin123)${NC}"
echo ""
print_info "📝 Commandes utiles:"
echo -e "${WHITE}  kubectl get pods -n onlyflick${NC}"
echo -e "${WHITE}  kubectl logs -n onlyflick -l app=onlyflick-backend -f${NC}"
echo -e "${WHITE}  kubectl port-forward -n onlyflick svc/onlyflick-backend-service 8080:8080${NC}"
echo -e "${WHITE}  curl http://localhost:8080/health${NC}"
echo ""
print_info "🧹 Pour nettoyer:"
echo -e "${WHITE}  kubectl delete namespace onlyflick${NC}"
echo -e "${WHITE}  helm uninstall monitoring -n monitoring${NC}"