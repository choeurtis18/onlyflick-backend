# OnlyFlick - Backend API

## PROJET COMPLET DÉPLOYÉ ET FONCTIONNEL

OnlyFlick est une plateforme sociale complète connectant créateurs de contenu et abonnés. Ce projet full-stack combine un backend Go robuste avec une interface Flutter moderne, le tout déployé sur Kubernetes avec monitoring intégré.

## STATUT DU PROJET : 100% OPÉRATIONNEL

- **Frontend Flutter** : Interface MatchMaker déployée et accessible
- **Backend Go** : API REST + WebSocket fonctionnels  
- **Infrastructure** : Kubernetes + Monitoring Grafana/Prometheus
- **Tests** : Tests unitaires + Performances + E2E validés
- **Sécurité** : JWT + AES + CORS configurés

## Stack technique

- **Frontend** : Flutter Web (Interface MatchMaker)
- **Backend** : Go (Golang) avec framework Chi
- **Base de données** : PostgreSQL (Neon Cloud)
- **Authentification** : JWT + Chiffrement AES
- **WebSocket** : Messagerie temps réel
- **Infrastructure** : Kubernetes (Docker Desktop)
- **Monitoring** : Prometheus + Grafana
- **Tests** : Suite complète (unitaires, intégration, E2E, performance)
- **Upload** : ImageKit pour les médias

## Prérequis

- **Go 1.22+**
- **Docker & Docker Compose** (ou Kubernetes)
- **migrate CLI** (pour les migrations SQL)
- **PostgreSQL 16** (local ou distant)
- **(optionnel)** accès à ImageKit pour les uploads de médias en production

## Installation & Build

1. **Clonez le repo**

```bash
git clone https://github.com/choeurtis18/onlyflick-backend.git
cd onlyflick-backend
```

2. **Installez les dépendances**

```bash
go mod download
```

3. **Compilez l'API**

```bash
go build -v ./...
```

## Exécution locale

1. **Lancez PostgreSQL** (via Docker Compose ou Kubernetes)

```bash
docker run --rm -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=onlyflick_test -p 5432:5432 postgres:16
```

2. **Créez la base et appliquez les migrations**

```bash
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/onlyflick_test?sslmode=disable"
migrate -path migrations -database "${DATABASE_URL}" up
```

3. **Définissez la clé secrète JWT**

```bash
export SECRET_KEY="votre_cle_32_caracteres_ici"
```

4. **Démarrez l'API**

```bash
go run ./cmd/server
# ou, si vous avez compilé :
./onlyflick-backend
```

L'API tournera par défaut sur `:8080`.

## Infrastructure Kubernetes

### Containerisation

- **Docker** - Containerisation des applications
- **Multi-stage builds** - Optimisation taille images
- **Alpine Linux** - Images légères et sécurisées
- **Multi-architecture** - Support AMD64 + ARM64

### Orchestration Kubernetes

- **Docker Desktop Kubernetes** - Cluster local de développement
- **Namespace isolation** - Séparation des environnements
- **Deployment controllers** - Gestion des réplicas
- **Services & LoadBalancing** - Exposition des applications
- **ConfigMaps & Secrets** - Gestion configuration sécurisée

### Exemple de déploiement Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: onlyflick-backend }
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: backend
          image: barrydevops/onlyflick-backend:latest
          env:
            - name: DATABASE_URL
              value: postgresql://user:pass@postgres-svc:5432/onlyflick_prod?sslmode=require
            - name: SECRET_KEY
              valueFrom:
                secretKeyRef: { name: onlyflick-secrets, key: jwt-key }
          ports: [{ containerPort: 8080 }]
```

## Monitoring & Observabilité

### Stack de monitoring

- **Prometheus** - Collecte et stockage métriques time-series
<img width="1794" height="1016" alt="Prometheus_only_backend" src="https://github.com/user-attachments/assets/1af10b2c-acdb-4bec-8449-a38e870eb0c7" />
- **Sentry** - Collecte des erreurs côté Front
<img width="1851" height="971" alt="Sentry_error_flutter" src="https://github.com/user-attachments/assets/86f509e5-78d4-4832-a1d3-90277f6253a4" />

- **Grafana** - Dashboards et visualisation métriques
  
- **Node Exporter** - Métriques système (CPU, RAM, Disk)
  
- **AlertManager** - Gestion et routing des alertes
  
<img width="1920" height="1080" alt="Monitoring_Grafana_OnlyFlickApp" src="https://github.com/user-attachments/assets/1d028ccb-9187-4708-9b12-3a742a93c06a" />

- **Kube-State-Metrics** - Métriques état cluster Kubernetes

<img width="1794" height="1016" alt="Kubernetes_API_Server" src="https://github.com/user-attachments/assets/dd1512fc-f858-42a7-9493-cd06239e87a9" />
<img width="1794" height="1016" alt="Kubernetes_Namespace_Monitoring" src="https://github.com/user-attachments/assets/9fc66901-1b72-486c-91c6-8eed77ef1711" />


### Métriques collectées

- Métriques système (CPU, mémoire, disque, réseau)
- Métriques applicatives (latence, throughput, erreurs)
- Métriques Kubernetes (pods, nodes, deployments)
- Métriques business (utilisateurs, posts, messages)

## Tests

### Tests unitaires

```bash
go test ./tests/unit/... -v
```

### Tests de performance

```bash
go test ./tests/performance/... -v
```

### Tests E2E

```bash
go test ./tests/e2e/... -v
```

### Toutes les suites de tests

```bash
go test ./tests/... -v
```

## 🐳 Docker

### Build de l'image

```bash
docker build -t onlyflick-backend:latest .
```

## CI/CD & Automation

### GitHub Actions Pipeline

- **Déclencheurs multiples** - Push, PR, manual dispatch
- **Tests parallèles** - Exécution optimisée en matrice
- **Build multi-architecture** - Support AMD64/ARM64
- **Déploiement automatisé** - Staging → Production
- **Rollback automatique** - En cas d'échec déploiement

### Workflow phases

Dans `.github/workflows/ci.yml`, la pipeline:

1. **Build** → `go build ./...`
2. **Migrations** → `migrate up`
3. **Tests** → unitaires, perf, e2e
4. **(sur main) docker** → construction + push image multi-arch

## Outils de développement

### Development Environment

- **Visual Studio Code** - IDE principal
- **Go extensions** - Débogage et IntelliSense
- **Flutter extensions** - Hot reload et debugging
- **PowerShell scripts** - Automatisation locale
- **Docker Desktop** - Environnement containerisé local

## Networking & DNS

### Configuration Grafana

```bash
kubectl -n monitoring port-forward svc/prometheus-grafana 3000:80
```

### Prometheus

```bash
kubectl -n monitoring port-forward svc/prometheus-operated 9090:9090
```

Récupérer les identifiants :

```bash
echo "User: admin"
echo "Password: $(kubectl get secret grafana-admin --namespace monitoring -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 -d)"
```

### FÉLICITATIONS

Votre plateforme sociale **OnlyFlick/MatchMaker** est maintenant **100% déployée et opérationnelle** ! L'application combine une interface Flutter moderne avec un backend Go robuste, le tout orchestré sur Kubernetes avec monitoring intégré.

**Prêt pour la production !**

---

**Dernière mise à jour : 10 juillet 2025 - Déploiement réussi avec succès**
