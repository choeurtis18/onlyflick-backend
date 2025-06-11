# 🚀 Guide de déploiement OnlyFlick - Checklist complète

## ✅ **Checklist pré-déploiement**

### 1. Environnement local
- [ ] Docker Desktop installé et démarré
- [ ] Kubernetes activé dans Docker Desktop  
- [ ] kubectl installé et fonctionnel
- [ ] Helm installé
- [ ] Flutter installé (pour le frontend)
- [ ] Go 1.21+ installé

### 2. Configuration
- [ ] Fichier `.env` configuré avec toutes les variables
- [ ] DNS local configuré dans le fichier hosts
- [ ] Ports 80, 443, 3000, 8080 disponibles

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
notepad C:\Windows\System32\drivers\etc\hosts

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

### Étape 4: Déploiement OnlyFlick
```bash
# Déploiement automatique
.\scripts\deploy-full-stack.ps1

# OU déploiement manuel
kubectl create secret generic onlyflick-backend-secret --from-env-file=.env -n onlyflick
docker build -t onlyflick-backend:latest .
kubectl apply -f k8s/backend/
kubectl apply -f k8s/frontend/
kubectl apply -f k8s/ingress/
```

### Étape 5: Monitoring
```bash
# Installer Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --set grafana.adminPassword=admin123

# Appliquer l'ingress Grafana
kubectl apply -f k8s/monitoring/grafana-ingress.yaml
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
go test ./tests/... -v

# Test de l'interface
# Ouvrir http://onlyflick.local dans le navigateur
```

## 🚨 **Résolution de problèmes courants**

### Erreur 503 Service Unavailable
```bash
# Diagnostic
kubectl describe ingress onlyflick-ingress -n onlyflick

# Solution
.\scripts\fix-503.ps1
```

### Pods en erreur
```bash
# Vérifier les logs
kubectl logs -n onlyflick -l app=onlyflick-backend
kubectl describe pod -n onlyflick -l app=onlyflick-backend

# Redémarrer
kubectl rollout restart deployment onlyflick-backend -n onlyflick
```

### Problème DNS
```bash
# Vérifier la résolution
nslookup onlyflick.local

# Vérifier le fichier hosts
type C:\Windows\System32\drivers\etc\hosts
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
- [ ] Tests automatisés passent (28/28)
- [ ] Logs backend sans erreur
- [ ] Pods backend et frontend en status Running

**🚀 Si tous les points sont validés, le déploiement est réussi !**
