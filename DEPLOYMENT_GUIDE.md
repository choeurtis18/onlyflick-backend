# 🚀 Guide de déploiement OnlyFlick - Checklist complète

## ✅ **Checklist pré-déploiement**

### 1. Environnement local

- [ ] Docker Engine installé et démarré (ou Docker Desktop pour macOS/Windows)
- [ ] Kubernetes activé (Minikube, K3s, Kind ou Docker Desktop)
- [ ] kubectl installé et fonctionnel (v1.28+)
- [ ] Helm installé (v3.12+)
- [ ] Flutter installé (v3.16+) pour le frontend
- [ ] Go 1.21+ installé

### 2. Configuration

- [ ] Fichier `.env` configuré avec toutes les variables (voir `.env.example`)
- [ ] DNS local configuré dans le fichier hosts
- [ ] Ports 80, 443, 3000, 8080 disponibles
- [ ] PostgreSQL accessible (local ou cloud)

## 🎯 **Déploiement étape par étape**

### Étape 1: Préparation

```bash
# Vérifier Docker
docker info

# Vérifier Kubernetes  
kubectl cluster-info

# Créer le namespace
kubectl create namespace onlyflick
```

### Étape 2: DNS local (OBLIGATOIRE)

```bash
# Éditer le fichier hosts en tant qu'administrateur
sudo nano /etc/hosts

# Ajouter ces lignes :
127.0.0.1 onlyflick.local
127.0.0.1 api.onlyflick.local
127.0.0.1 grafana.local
```

### Étape 3: Ingress Controller

```bash
# Installer NGINX Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Attendre qu'il soit prêt
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
```

### Étape 4: Base de données

```bash
# Créer le secret PostgreSQL
kubectl create secret generic postgres-secret -n onlyflick \
  --from-literal=POSTGRES_PASSWORD=onlyflick123 \
  --from-literal=POSTGRES_USER=onlyflick \
  --from-literal=POSTGRES_DB=onlyflick

# Déployer PostgreSQL
kubectl apply -f k8s/database/

# Vérifier que PostgreSQL est prêt
kubectl wait --for=condition=ready pod -l app=postgres -n onlyflick --timeout=120s
```

### Étape 5: Déploiement OnlyFlick

```bash
# Créer le secret avec les variables d'environnement
kubectl create secret generic onlyflick-backend-secret --from-env-file=.env -n onlyflick

# Construire et déployer le backend
docker build -t onlyflick-backend:latest

# Déployer le backend
kubectl apply -f k8s/backend/

# Déployer le frontend
kubectl apply -f k8s/frontend/

# Déployer l'ingress
kubectl apply -f k8s/ingress/
```

### Étape 6: Monitoring

```bash
# Installer Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --set grafana.adminPassword=admin123

# Appliquer l'ingress Grafana
kubectl apply -f k8s/monitoring/
```

## 🔍 **Vérifications post-déploiement**

### Tests de connectivité

```bash
# 1. Vérifier les pods
kubectl get pods -n onlyflick

# 2. Tester l'API
curl http://api.onlyflick.local/health

# 3. Tester l'application
curl http://onlyflick.local

# 4. Vérifier Grafana
curl http://grafana.local
```

### Tests fonctionnels

```bash
# Tests automatisés
cd /home/barry/Documents/onlyflick-backend
go test ./tests/... -v

# Test de l'interface
# Ouvrir http://onlyflick.local dans le navigateur
```

## 🚨 **Résolution de problèmes courants**

### Erreur 503 Service Unavailable

```bash
# Diagnostic
kubectl describe ingress onlyflick-ingress -n onlyflick

# Solution pour problèmes d'ingress
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission

# Redéployer l'ingress si nécessaire
kubectl apply -f k8s/ingress/
```

### Pods en erreur

```bash
# Vérifier les logs
kubectl logs -n onlyflick -l app=onlyflick-backend
kubectl describe pod -n onlyflick -l app=onlyflick-backend

# Redémarrer
kubectl rollout restart deployment onlyflick-backend -n onlyflick
```

### Problème de connexion à la base de données

```bash
# Vérifier l'état de PostgreSQL
kubectl get pods -n onlyflick -l app=postgres
kubectl describe pvc pgdata-postgres-0 -n onlyflick

# Vérifier les logs
kubectl logs -n onlyflick -l app=postgres

# Vérifier que le paramètre sslmode=require est présent dans l'URL de connexion
kubectl get secret onlyflick-backend-secret -n onlyflick -o jsonpath='{.data.DATABASE_URL}' | base64 --decode
```

## 📱 **URLs finales**

Une fois le déploiement réussi, ces URLs doivent être accessibles :

- **🎨 Application** : http://onlyflick.local
- **🚀 API** : http://api.onlyflick.local  
- **📊 Monitoring** : http://grafana.local (admin/admin123)

## 🎉 **Validation finale**

Checklist de validation :

- [ ] Interface Flutter accessible sur http://onlyflick.local
- [ ] API répond sur http://api.onlyflick.local/health
- [ ] Grafana accessible sur http://grafana.local
- [ ] Tests automatisés passent
- [ ] Logs backend sans erreur
- [ ] Pods backend et frontend en status Running
- [ ] Base de données PostgreSQL connectée et fonctionnelle

**🚀 Si tous les points sont validés, le déploiement est réussi !**
